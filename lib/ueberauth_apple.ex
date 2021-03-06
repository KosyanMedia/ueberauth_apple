defmodule UeberauthApple do
  @default_expires_in 86400 * 180
  @public_key_url "https://appleid.apple.com/auth/keys"
  @alg "RS256"

  def fields_from_id_token(id_token) do
    with {:ok, %{body: response_body}} <- HTTPoison.get(@public_key_url),
         {true, %JOSE.JWT{fields: fields}, _jws} <-
           Poison.decode!(response_body)["keys"]
           |> get_fields(id_token) do
      fields
    end
  end

  defp get_fields(keys, token) do
    keys
    |> Enum.reduce(nil, fn key, acc ->
        case acc do
          res={true, _, _jws} -> res
          _ -> JOSE.JWT.verify(key, token)
        end
      end)
  end

  def verify_token(key, token) do
    JsonWebToken.verify(token, alg: @alg, key: key)
  end

  @doc """
  Generates client secret.
  """
  def generate_client_secret(
        %{client_id: client_id, key_id: key_id, team_id: team_id, private_key: private_key} =
          options
      ) do
    opts = Enum.into(options, %{expires_in: @default_expires_in})
    now = DateTime.utc_now() |> DateTime.to_unix()
    jwk = JOSE.JWK.from_pem(private_key)
    jws = %{"alg" => "ES256", "kid" => key_id}

    jwt = %{
      "iss" => team_id,
      "iat" => now,
      "exp" => now + opts[:expires_in],
      "aud" => "https://appleid.apple.com",
      "sub" => client_id
    }

    {_, token} = jwk |> JOSE.JWT.sign(jws, jwt) |> JOSE.JWS.compact()
    token
  end

  def generate_client_secret(opts) when is_list(opts),
      do: opts |> Enum.into(%{}) |> generate_client_secret()
end
