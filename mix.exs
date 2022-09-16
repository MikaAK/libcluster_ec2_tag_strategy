defmodule LibclusterEc2TagStrategy.MixProject do
  use Mix.Project

  def project do
    [
      app: :libcluster_ec2_tag_strategy,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_aws, "~> 2.0"},
      {:ex_aws_ec2, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:hackney, "~> 1.9"},
      {:elixir_xml_to_map, "~> 2.0"},
      {:error_message, "~> 0.2"}
    ]
  end
end
