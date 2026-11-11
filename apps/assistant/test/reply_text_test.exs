defmodule Assistant.Reply.TextTest do
  use ExUnit.Case, async: true

  alias Assistant.Reply.Text

  test "title stays inside 48 characters on a word boundary" do
    assert Text.clip_title("  короткий  ") == "короткий"

    long_word = String.duplicate("я", 60)
    assert String.length(Text.clip_title(long_word)) == 48

    head = "короткое слово "
    title = Text.clip_title(head <> String.duplicate("я", 40))
    assert title == "короткое слово"
  end

  test "overlap longer than 24 characters is cut" do
    tail = String.duplicate("q", 25)
    assert Text.remainder("zzz" <> tail, tail <> "!") == "!"

    short = String.duplicate("q", 24)
    assert Text.remainder("zzz" <> short, short <> "!") == short <> "!"
    assert Text.remainder("abc", "") == ""
  end
end
