defmodule Tempest.Lexicon.ExternalResolver.NetworkTest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias Tempest.Lexicon.ExternalResolver.Network

  @did "did:plc:abcdefghijklmnopqrstuvwxyz234567"
  @id "example.remote.record"
  @query "_lexicon.remote.example"
  @document %{
    "lexicon" => 1,
    "id" => @id,
    "defs" => %{
      "main" => %{
        "type" => "record",
        "key" => "any",
        "record" => %{"type" => "object", "properties" => %{"text" => %{"type" => "string"}}}
      }
    }
  }

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)
    Network.reset_cache!()

    old_identity_config = Application.get_env(:tempest, Tempest.Identity, [])

    Application.put_env(:tempest, Tempest.Identity,
      dns_lookup: fn
        "pds.example" -> {:ok, [{93, 184, 216, 34}]}
        "private.example" -> {:ok, [{127, 0, 0, 1}]}
        "plc.directory" -> {:ok, [{93, 184, 216, 34}]}
        _host -> {:error, :nxdomain}
      end
    )

    on_exit(fn ->
      Network.reset_cache!()
      Application.put_env(:tempest, Tempest.Identity, old_identity_config)
    end)

    :ok
  end

  test "resolves NSID authority through DNS, DID document, and PDS schema record" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.scheme == :https
      assert conn.host == "pds.example"
      assert conn.request_path == "/xrpc/com.atproto.repo.getRecord"
      assert conn.query_string =~ "collection=com.atproto.lexicon.schema"
      assert conn.query_string =~ "rkey=example.remote.record"

      json(conn, %{"value" => Map.put(@document, "$type", "com.atproto.lexicon.schema")})
    end)

    assert {:ok, @document} = Network.resolve(@id, resolver_opts())
  end

  test "resolves site.standard lexicons in the default external namespace set" do
    for id <- ~w(
           site.standard.document
           site.standard.graph.recommend
           site.standard.graph.subscription
           site.standard.publication
         ) do
      Network.reset_cache!()

      document = Map.put(@document, "id", id)
      query = "_lexicon." <> (id |> String.split(".") |> Enum.drop(-1) |> Enum.reverse() |> Enum.join("."))

      assert {:ok, ^document} =
               Network.resolve(id,
                 dns_txt_lookup: fn ^query -> ["did=#{@did}"] end,
                 did_document_lookup: fn @did ->
                   {:ok,
                    %{
                      "service" => [
                        %{"type" => "AtprotoPersonalDataServer", "serviceEndpoint" => "https://pds.example"}
                      ]
                    }}
                 end,
                 schema_record_lookup: fn _endpoint, @did, ^id -> {:ok, %{"value" => document}} end,
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end
  end

  test "rejects external resolution outside the default namespace set" do
    assert {:error, :not_allowed} =
             Network.resolve(@id,
               dns_txt_lookup: fn @query -> ["did=#{@did}"] end,
               did_document_lookup: fn @did ->
                 {:ok,
                  %{"service" => [%{"type" => "AtprotoPersonalDataServer", "serviceEndpoint" => "https://pds.example"}]}}
               end,
               req_options: [plug: {Req.Test, __MODULE__}]
             )
  end

  test "allows non-default namespaces when explicitly configured" do
    Req.Test.expect(__MODULE__, fn conn ->
      json(conn, %{"value" => Map.put(@document, "$type", "com.atproto.lexicon.schema")})
    end)

    assert {:ok, @document} = Network.resolve(@id, resolver_opts(allowed_namespaces: ["example.remote"]))
  end

  test "caches positive resolution results" do
    counter = start_counter!()

    opts =
      resolver_opts(
        schema_record_lookup: fn _endpoint, _did, _id ->
          increment_counter(counter)
          {:ok, %{"value" => @document}}
        end
      )

    assert {:ok, @document} = Network.resolve(@id, opts)
    assert {:ok, @document} = Network.resolve(@id, opts)
    assert counter_value(counter) == 1
  end

  test "caches negative resolution results" do
    counter = start_counter!()

    opts =
      resolver_opts(
        dns_txt_lookup: fn @query ->
          increment_counter(counter)
          []
        end
      )

    assert {:error, :not_found} = Network.resolve(@id, opts)
    assert {:error, :not_found} = Network.resolve(@id, opts)
    assert counter_value(counter) == 1
  end

  test "serves stale positive cache when refresh fails" do
    counter = start_counter!()

    opts =
      resolver_opts(
        positive_ttl_ms: -1,
        stale_ttl_ms: 60_000,
        schema_record_lookup: fn _endpoint, _did, _id ->
          case increment_counter(counter) do
            1 -> {:ok, %{"value" => @document}}
            _count -> {:error, :resolution_failed}
          end
        end
      )

    assert {:ok, @document} = Network.resolve(@id, opts)
    assert {:ok, @document} = Network.resolve(@id, opts)
    assert counter_value(counter) == 2
  end

  test "serializes concurrent refreshes for the same schema id" do
    counter = start_counter!()
    parent = self()

    opts =
      resolver_opts(
        schema_record_lookup: fn _endpoint, _did, _id ->
          send(parent, :fetch_started)
          increment_counter(counter)
          Process.sleep(25)
          {:ok, %{"value" => @document}}
        end
      )

    tasks = for _index <- 1..2, do: Task.async(fn -> Network.resolve(@id, opts) end)

    assert {:ok, @document} = Task.await(Enum.at(tasks, 0))
    assert {:ok, @document} = Task.await(Enum.at(tasks, 1))
    assert_receive :fetch_started
    refute_receive :fetch_started, 50
    assert counter_value(counter) == 1
  end

  test "rejects private PDS service endpoints before fetching schema records" do
    opts =
      resolver_opts(
        did_document_lookup: fn @did ->
          {:ok,
           %{"service" => [%{"type" => "AtprotoPersonalDataServer", "serviceEndpoint" => "https://private.example"}]}}
        end
      )

    assert {:error, :private_ip} = Network.resolve(@id, opts)
  end

  test "rejects redirects and oversized responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> put_resp_header("location", "https://pds.example/elsewhere")
      |> send_resp(302, "")
    end)

    assert {:error, :redirect_rejected} = Network.resolve(@id, resolver_opts())

    Network.reset_cache!()

    Req.Test.expect(__MODULE__, fn conn ->
      send_resp(conn, 200, String.duplicate("x", 128))
    end)

    assert {:error, :response_too_large} = Network.resolve(@id, resolver_opts(max_response_bytes: 32))
  end

  defp resolver_opts(overrides \\ []) do
    Keyword.merge(
      [
        dns_txt_lookup: fn @query -> ["did=#{@did}"] end,
        did_document_lookup: fn @did ->
          {:ok, %{"service" => [%{"type" => "AtprotoPersonalDataServer", "serviceEndpoint" => "https://pds.example"}]}}
        end,
        allowed_namespaces: ["example.remote"],
        req_options: [plug: {Req.Test, __MODULE__}]
      ],
      overrides
    )
  end

  defp json(conn, body) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(body))
  end

  defp start_counter! do
    start_supervised!({Agent, fn -> 0 end})
  end

  defp increment_counter(counter) do
    Agent.get_and_update(counter, fn value ->
      next = value + 1
      {next, next}
    end)
  end

  defp counter_value(counter), do: Agent.get(counter, & &1)
end
