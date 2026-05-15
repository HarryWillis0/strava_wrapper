defmodule StravaWrapper.Activity do
  @enforce_keys [:id, :name, :date, :type, :distance, :duration, :gear_id]

  defstruct [
    :id,
    :name,
    :date,
    :type,
    :distance,
    :duration,
    :gear_id,
    :gear_name
  ]
end
