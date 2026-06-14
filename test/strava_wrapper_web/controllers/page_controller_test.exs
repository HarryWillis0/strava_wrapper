defmodule StravaWrapperWeb.PageControllerTest do
  use StravaWrapperWeb.ConnCase

  test "GET / redirects to auth when no session", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/auth/strava"
  end
end
