if "#{Mix.env()}" =~ "test" and Code.ensure_loaded?(Cldr) do
  defmodule ExDoubleEntry.Cldr do
    use Cldr,
      locales: ["en"],
      default_locale: "en",
      providers: [Cldr.Number, Money]
  end
end
