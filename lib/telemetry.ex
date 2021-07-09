defmodule SpandexTesla.Telemetry do
  @moduledoc """
  Defines the `:telemetry` handlers to attach tracing to Tesla Telemetry.
  """

  @doc """
  Automatic installer. Call it from application.ex to trace all events generated by Tesla.
  """
  def attach do
    tesla_events = [
      [:tesla, :request, :start],
      [:tesla, :request, :stop],
      [:tesla, :request, :exception]
    ]

    :telemetry.attach_many("spandex-tesla-tracer", tesla_events, &SpandexTesla.handle_event/4, nil)
  end
end