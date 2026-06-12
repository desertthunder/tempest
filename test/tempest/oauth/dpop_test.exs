defmodule Tempest.OAuth.DpopTest do
  use Tempest.DataCase, async: false

  alias Tempest.OAuth.Dpop

  @method "POST"
  @url "https://pds.example.com/oauth/token"

  test "accepts a signed ES256 proof and returns the key thumbprint" do
    key = Tempest.DpopProof.key()
    proof = Tempest.DpopProof.proof(@method, @url, Dpop.issue_nonce(), key: key)
    public_jwk = Tempest.DpopProof.public_jwk(key)

    assert {:ok, expected_jkt} = Dpop.jwk_thumbprint(public_jwk)
    assert {:ok, %{jkt: ^expected_jkt, jwk: ^public_jwk}} = Dpop.verify_proof(proof, @method, @url)
  end

  test "accepts supported DPoP signing algorithms" do
    cases = [
      {"ES384", JOSE.JWK.generate_key({:ec, "P-384"})},
      {"ES512", JOSE.JWK.generate_key({:ec, "P-521"})},
      {"RS256", JOSE.JWK.generate_key({:rsa, 2048})},
      {"PS256", JOSE.JWK.generate_key({:rsa, 2048})}
    ]

    for {alg, key} <- cases do
      proof = Tempest.DpopProof.proof(@method, @url, Dpop.issue_nonce(), key: key, alg: alg)

      assert {:ok, %{jkt: jkt}} = Dpop.verify_proof(proof, @method, @url)
      assert is_binary(jkt)
    end
  end

  test "modified payload fails signature verification" do
    proof = Tempest.DpopProof.proof(@method, @url, Dpop.issue_nonce())
    tampered = replace_payload(proof, %{"htm" => "GET"})

    assert {:error, :invalid_dpop} = Dpop.verify_proof(tampered, @method, @url)
  end

  test "wrong embedded key fails signature verification" do
    signing_key = Tempest.DpopProof.key()
    other_key = Tempest.DpopProof.key()

    proof =
      Tempest.DpopProof.proof(@method, @url, Dpop.issue_nonce(),
        key: signing_key,
        jwk: Tempest.DpopProof.public_jwk(other_key)
      )

    assert {:error, :invalid_dpop} = Dpop.verify_proof(proof, @method, @url)
  end

  test "wrong alg is rejected before claim validation" do
    proof = Tempest.DpopProof.proof(@method, @url, Dpop.issue_nonce())
    tampered = replace_header(proof, %{"alg" => "HS256"})

    assert {:error, :unsupported_dpop_alg} = Dpop.verify_proof(tampered, @method, @url)
  end

  test "reused nonce is rejected" do
    nonce = Dpop.issue_nonce()
    proof = Tempest.DpopProof.proof(@method, @url, nonce)

    assert {:ok, _proof} = Dpop.verify_proof(proof, @method, @url)
    assert {:error, :invalid_dpop_nonce} = Dpop.verify_proof(proof, @method, @url)
  end

  test "wrong htu is rejected" do
    proof = Tempest.DpopProof.proof(@method, "https://pds.example.com/oauth/par", Dpop.issue_nonce())

    assert {:error, :invalid_dpop} = Dpop.verify_proof(proof, @method, @url)
  end

  test "wrong htm is rejected" do
    proof = Tempest.DpopProof.proof("GET", @url, Dpop.issue_nonce())

    assert {:error, :invalid_dpop} = Dpop.verify_proof(proof, @method, @url)
  end

  defp replace_header(proof, fields), do: replace_part(proof, 0, fields)
  defp replace_payload(proof, fields), do: replace_part(proof, 1, fields)

  defp replace_part(proof, index, fields) do
    parts = String.split(proof, ".")

    updated_part =
      parts
      |> Enum.at(index)
      |> Base.url_decode64!(padding: false)
      |> Jason.decode!()
      |> Map.merge(fields)
      |> Jason.encode!()
      |> Base.url_encode64(padding: false)

    parts
    |> List.replace_at(index, updated_part)
    |> Enum.join(".")
  end
end
