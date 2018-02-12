defmodule PerQ do
    use Application

    def start(_type, _args) do

        IO.puts("1")

        PerQ.Supervisor.start_link()
    end
end
