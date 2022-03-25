defmodule BlockScoutWeb.API.RPC.RPCView do
  use BlockScoutWeb, :view

  def render("show.json", %{data: data}) do
    %{
      "status" => "1",
      "success" => :true,
      "message" => "OK",
      "result" => data
    }
  end

  def render("show_value.json", %{data: data}) do
    {value, _} =
      data
      |> Float.parse()

    value
  end

  def render("error.json", %{error: message} = assigns) do
    %{
      "status" => "0",
      "success" => :false,
      "message" => message,
      "result" => Map.get(assigns, :data)
    }
  end
end
