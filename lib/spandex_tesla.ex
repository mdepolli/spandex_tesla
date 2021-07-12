defmodule SpandexTesla do
  @moduledoc """
  Tracing integration between [tesla](https://hex.pm/packages/tesla) and [spandex](https://hex.pm/packages/spandex).
  It leverages telemetry to get the [tesla](https://hex.pm/packages/tesla) events and trace them with [spandex](https://hex.pm/packages/spandex).

  ## Usage

  Configure the correct tracer to be used:

  ```elixir
  config :spandex_tesla
    service: :tesla, # Optional
    tracer: MyApp.Tracer, # Required
  ```

  Include the [telemetry middleware](https://hexdocs.pm/tesla/Tesla.Middleware.Telemetry.html#content) in your tesla client:

  ```elixir
  defmodule MyClient do
    use Tesla

    plug Tesla.Middleware.Telemetry

  end
  ```

  Attach the telemetry handler:

  ```elixir
  # in application.ex
  :telemetry.attach(
    "spandex-tesla-tracer",
    [:tesla, :request, :start],
    &SpandexTesla.handle_event/4,
    nil
  )
  ```

  """

  defmodule Error do
    @moduledoc """
    Struct used to identify the errors.
    """
    defexception [:message]
  end

  @doc """
  Telemetry handler. Attach it to the telemetry tesla events in order to trace the tesla calls.
  """
  def handle_event([:tesla, :request, :start], _measurements, _metadata, _config) do
    if tracer().current_trace_id([]) do
      tracer().start_span("request", [])

      Logger.metadata(
        trace_id: to_string(tracer().current_trace_id([])),
        span_id: to_string(tracer().current_span_id([]))
      )
    end
  end

  def handle_event([:tesla, :request, :stop], measurements, metadata, _config) do
    if tracer().current_trace_id([]) do
      now = clock_adapter().system_time()
      %{duration: duration} = measurements
      %{status: status, url: url, method: method} = metadata[:env]
      upcased_method = method |> to_string() |> String.upcase()

      tracer().update_span(
        start: now - duration,
        completion_time: now,
        service: service(),
        resource: "#{upcased_method} #{url}",
        type: :web,
        http: [
          url: url,
          status_code: status,
          method: upcased_method
        ]
      )

      tracer().finish_span([])
    end
  end

  def handle_event([:tesla, :request, :exception], _measurements, metadata, _config) do
    if tracer().current_trace_id([]) do
      %{reason: reason} = metadata

      tracer().span_error(%Error{message: inspect(reason)}, nil, [])

      tracer().finish_span([])

      Logger.metadata(
        trace_id: to_string(tracer().current_trace_id([])),
        span_id: to_string(tracer().current_span_id([]))
      )
    end
  end

  defp tracer do
    Application.fetch_env!(:spandex_tesla, :tracer)
  end

  defp service do
    Application.get_env(:spandex_tesla, :service, :tesla)
  end

  defp clock_adapter do
    Application.get_env(:spandex_tesla, :clock_adapter, System)
  end
end
