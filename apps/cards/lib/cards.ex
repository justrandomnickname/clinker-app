defmodule Cards do
  use GenServer

  require Logger

  alias Cards.{Cache, Contract, Dispatch, Index, Remote, Rules, Write}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def instructions, do: Contract.instructions()
  def tools, do: Contract.tools()
  def mcp_token, do: Contract.mcp_token()
  def explain(reason), do: Contract.explain(reason)
  def pack(result), do: Contract.pack(result)

  def list(tags) when is_list(tags) do
    GenServer.call(__MODULE__, {:list, Rules.clean_tags(tags)}, 60_000)
  end

  def get(slug) when is_binary(slug) do
    if Rules.token?(slug) do
      GenServer.call(__MODULE__, {:get, slug}, 60_000)
    else
      {:error, :missing}
    end
  end

  def create(slug, title, tags, source, body) do
    case Rules.cast_create(slug, title, tags, source, body) do
      {:ok, fields} -> GenServer.call(__MODULE__, {:create, fields}, 120_000)
      :error -> Contract.invalid()
    end
  end

  def update(slug, title, tags, body) do
    case Rules.cast_update(slug, title, tags, body) do
      {:ok, fields} -> GenServer.call(__MODULE__, {:update, fields}, 120_000)
      :error -> Contract.invalid()
    end
  end

  def dispatch(name, args) do
    case Dispatch.call(name, args) do
      {:list, tags} -> list(tags)
      {:get, slug} -> get(slug)
      {:create, fields} -> GenServer.call(__MODULE__, {:create, fields}, 120_000)
      {:update, fields} -> GenServer.call(__MODULE__, {:update, fields}, 120_000)
      :invalid -> Contract.invalid()
    end
  end

  @impl true
  def init(_opts) do
    root = config()[:root] || Path.join(System.tmp_dir!(), "clinker-cards")

    {:ok, %{status: :booting, root: root, tip: nil, cards: %{}, by_tag: %{}}, {:continue, :boot}}
  end

  @impl true
  def handle_continue(:boot, state) do
    state =
      try do
        boot(state)
      rescue
        error ->
          Logger.warning("cards boot failed: #{Exception.message(error)}")
          unavailable(state)
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:list, tags}, _from, %{status: :ready} = state) do
    {:reply, {:ok, Index.headers(state.cards, state.by_tag, tags)}, state}
  end

  def handle_call({:list, _tags}, _from, state) do
    {:reply, {:error, :unavailable}, state}
  end

  def handle_call({:get, slug}, _from, %{status: :ready} = state) do
    content = Cache.read(state.root, slug) || ""
    {:reply, Index.present(state.cards, slug, content), state}
  end

  def handle_call({:get, _slug}, _from, state) do
    {:reply, {:error, :unavailable}, state}
  end

  def handle_call({:create, fields}, _from, state), do: reply(Write.run(state, :create, fields))
  def handle_call({:update, fields}, _from, state), do: reply(Write.run(state, :update, fields))

  defp boot(state) do
    case Remote.credentials() do
      {:ok, url, token} ->
        case Remote.fetch(url, token) do
          {:ok, tip, files} ->
            Cache.install(state.root, files)
            {cards, by_tag} = Index.build(files)
            %{state | status: :ready, tip: tip, cards: cards, by_tag: by_tag}

          :error ->
            unavailable(state)
        end

      :error ->
        unavailable(state)
    end
  end

  defp unavailable(state), do: %{state | status: :unavailable}

  defp reply({:ok, result, state}), do: {:reply, {:ok, result}, state}
  defp reply({:error, :invalid, state}), do: {:reply, Contract.invalid(), state}
  defp reply({:error, reason, state}), do: {:reply, {:error, reason}, state}

  defp config, do: Application.get_env(:cards, :repo, %{})
end
