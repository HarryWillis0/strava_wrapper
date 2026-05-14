defmodule StravaWrapperWeb.PageController do
  use StravaWrapperWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
