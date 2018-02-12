defmodule PerQ.Supervisor do
    use Supervisor

    def start_link() do

        IO.puts("2")

        Supervisor.start_link(__MODULE__, [])
    end

    def init(_) do

        IO.puts("3")

        children = [
            worker(PerQ.Queue, [], restart: :permanent)
        ]

        supervise(children, strategy: :one_for_one)
    end
end