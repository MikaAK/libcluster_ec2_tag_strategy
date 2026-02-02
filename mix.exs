defmodule LibclusterEc2TagStrategy.MixProject do
  use Mix.Project

  def project do
    [
      app: :libcluster_ec2_tag_strategy,
      version: "0.1.4",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "LibCluster EC2 Tag Strategy to help nodes cluster together with different topologies",
      docs: docs(),
      package: package()
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
      {:libcluster, "~> 3.3"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_ec2, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:hackney, "~> 1.9"},
      {:elixir_xml_to_map, "~> 3.0"},
      {:error_message, "~> 0.2"},

      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Mika Kalathil"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/MikaAK/libcluster_ec2_tag_strategy"},
      files: ~w(mix.exs README.md CHANGELOG.md lib config)
    ]
  end

  defp docs do
    [
      main: "Cluster.Strategy.EC2Tag",
      source_url: "https://github.com/MikaAK/libcluster_ec2_tag_strategy"
    ]
  end
end
