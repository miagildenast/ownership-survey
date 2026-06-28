defmodule OwnershipAshChatWeb.PageController do
  use OwnershipAshChatWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
