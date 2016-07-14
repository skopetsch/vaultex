defmodule Vaultex.Client do
  use GenServer
  @version "v1"
  @httpoison Application.get_env(:vaultex, :httpoison)

  def start_link() do
    GenServer.start_link(__MODULE__, %{progress: "starting"}, name: :vaultex)
  end

  def init(state) do
    url = "#{get_env(:scheme)}://#{get_env(:host)}:#{get_env(:port)}/#{@version}/"
    {:ok, Map.merge(state, %{url: url})}
  end

  def auth() do
    GenServer.call(:vaultex, {:auth})
  end

  def read(key) do
    GenServer.call(:vaultex, {:read, key})
  end

  def handle_call({:read, key}, _from, state) do
    request(:get, "#{state.url}#{key}", %{}, [{"X-Vault-Token", state.token}])
    |> handle_read_vault_response(state)
  end

  def handle_call({:auth}, _from, state) do
    app_id = Application.get_env(:vaultex, :app_id, nil)
    user_id = Application.get_env(:vaultex, :user_id, nil)

    request(:post, "#{state.url}auth/app-id/login", %{app_id: app_id, user_id: user_id}, [{"Content-Type", "application/json"}])
    |> handle_auth_vault_response(state)
  end

  defp handle_read_vault_response({:ok, response}, state) do
    case response.body |> Poison.Parser.parse! do
      %{"data" => data} -> {:reply, {:ok, data["value"]}, Map.merge(state, %{value: data["value"]})}
      %{"errors" => messages} -> {:reply, {:error, messages}, Map.merge(state, %{messages: messages})}
    end
  end

  defp handle_auth_vault_response({:ok, response}, state) do
    case response.body |> Poison.Parser.parse! do
      %{"errors" => messages} -> {:reply, {:error, messages}, Map.merge(state, %{messages: messages})}
      %{"auth" => properties} -> {:reply, {:ok, :authenticated}, Map.merge(state, %{token: properties["client_token"]})}
    end
  end

  defp handle_auth_vault_response({_, _}, state) do
      {:reply, {:error, ["Bad response from vault"]}, Map.merge(state, %{messages: "Bad response from vault"})}
  end

  defp request(method, url, params = %{}, headers) do
    @httpoison.request(method, url, Poison.Encoder.encode(params, []), headers)
  end

  defp get_env(:host) do
    System.get_env("VAULT_HOST") || Application.get_env(:vaultex, :host) || "localhost"
  end
  defp get_env(:port) do
      System.get_env("VAULT_PORT") || Application.get_env(:vaultex, :port) || 8200
  end
  defp get_env(:scheme) do
      System.get_env("VAULT_SCHEME") || Application.get_env(:vaultex, :scheme) || "http"
  end

end
