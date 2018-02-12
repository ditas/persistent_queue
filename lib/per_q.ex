defmodule PerQ do
    use Application

    def start(_type, _args) do
        PerQ.Supervisor.start_link()
    end
end
