defmodule StravaWrapperWeb.PageControllerTest do
  use StravaWrapperWeb.ConnCase

  test "GET / renders activity list page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Activities"
  end
end
