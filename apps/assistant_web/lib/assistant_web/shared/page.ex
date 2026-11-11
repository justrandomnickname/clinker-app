defmodule AssistantWeb.Shared.Page do
  defmacro __using__(_opts) do
    request = Module.concat(__CALLER__.module, Request)
    screen = Module.concat(__CALLER__.module, Screen)

    quote do
      def handle_async(name, {:ok, value}, socket) do
        {:noreply, unquote(request).loaded(socket, name, value)}
      end

      def handle_async(name, {:exit, reason}, socket) do
        {:noreply, unquote(request).failed(socket, name, reason)}
      end

      def handle_info(message, socket) do
        {:noreply, unquote(screen).deliver(socket, message)}
      end

      defoverridable handle_async: 3, handle_info: 2
    end
  end
end
