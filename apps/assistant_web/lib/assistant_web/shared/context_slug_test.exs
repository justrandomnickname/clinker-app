defmodule AssistantWeb.Shared.ContextSlugTest do
  use ExUnit.Case, async: true

  alias AssistantWeb.Shared.ContextSlug

  test "russian words become a latin slug" do
    assert ContextSlug.canonical("бытовое") == {:ok, "bytovoe"}
    assert ContextSlug.canonical("программирование") == {:ok, "programmirovanie"}
    assert ContextSlug.canonical("Бытовое дело") == {:ok, "bytovoe_delo"}
    assert ContextSlug.canonical("чат 2") == {:ok, "chat_2"}
    assert ContextSlug.canonical("  ёж  ") == {:ok, "ezh"}
  end

  test "latin input is kept and lowercased" do
    assert ContextSlug.canonical("misc") == {:ok, "misc"}
    assert ContextSlug.canonical("Misc") == {:ok, "misc"}
  end

  test "no_context and an empty result are refused" do
    assert ContextSlug.canonical("no_context") == :reserved
    assert ContextSlug.canonical("No Context") == :reserved
    assert ContextSlug.canonical("ъь") == :error
    assert ContextSlug.canonical("   ") == :error
    assert ContextSlug.canonical("!!!") == :error
  end

  test "a slug is at most 64 characters" do
    assert {:ok, slug} = ContextSlug.canonical(String.duplicate("а", 80))
    assert slug == String.duplicate("a", 64)
  end
end
