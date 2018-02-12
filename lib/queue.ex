defmodule PerQ.Queue do
    use GenServer
    require Record

    Record.defrecord :q_change, [timestamp: nil, operation_num: nil, operation: nil]
    @tab :history

    def start_link() do

        IO.puts("4")

        GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    def init(_opts) do

        IO.puts("5")

        :ets.new(@tab, [:bag, :protected, :named_table, {:keypos, q_change(:timestamp)}])
        {:ok, %{:stack => [], :operation_num => 0, :await_acks => []}}
    end

    def handle_call({:add, value} = operation, _from, state) do
        current_stack = Map.get(state, :stack)
        current_operation_num = Map.get(state, :operation_num)

        timestamp = :erlang.system_time(:millisecond)
        new_operation_num = current_operation_num + 1
        new_change = q_change(timestamp: timestamp, operation_num: new_operation_num, operation: operation)
        :ets.insert(@tab, new_change)

        {:reply, {:ok, timestamp, new_operation_num}, Map.put(state, :stack, [value|current_stack])
            |> Map.put(:operation_num, new_operation_num)}
    end
    def handle_call({:get, ref}, _from, state) do
        current_stack = Map.get(state, :stack)
        current_operation_num = Map.get(state, :operation_num)
        current_awaits = Map.get(state, :await_acks)

        timestamp = :erlang.system_time(:millisecond)
        new_operation_num = current_operation_num + 1

        [h|t] = :lists.reverse(current_stack)

        IO.inspect(t)

        :timer.send_after(3000, {:rejection_timeout, ref})

        {:reply, {:ok, h, timestamp, new_operation_num}, Map.put(state, :stack, :lists.reverse(t))
            |> Map.put(:operation_num, new_operation_num)
            |> Map.put(:await_acks, [{ref, h, timestamp, new_operation_num}|current_awaits])}
    end
    def handle_call(_msg, _from, state) do
        {:reply, :ok, state}
    end

    def handle_cast(:state, state) do

        IO.inspect(state)

        {:noreply, state}
    end
    def handle_cast(_msg, state) do
        {:noreply, state}
    end

    def handle_info({:rejection_timeout, ref}, state) do

        IO.puts("timeout #{ref}")

        current_stack = Map.get(state, :stack)
        current_awaits = Map.get(state, :await_acks)
        state1 = case List.keytake(current_awaits, ref, 0) do
            {{_ref, value, _timestamp, _new_operation_num}, new_awaits} ->
                Map.put(state, :stack, [value|current_stack])
                |> Map.put(:await_acks, new_awaits)
            _ ->
                state
        end
        {:noreply, state1}
    end
    def handle_info({:ack, ref}, state) do

        IO.puts("ack #{ref}")

        current_awaits = Map.get(state, :await_acks)
        state1 = case List.keytake(current_awaits, ref, 0) do
            {{_ref, _value, timestamp, new_operation_num}, new_awaits} ->

                new_change = q_change(timestamp: timestamp, operation_num: new_operation_num, operation: {:get, ref})
                :ets.insert(@tab, new_change)

                Map.put(state, :await_acks, new_awaits)
            _ ->
                state
        end
        {:noreply, state1}
    end
    def handle_info(_msg, state) do
        {:noreply, state}
    end

    # External functions
    def add(value) do
        GenServer.call(__MODULE__, {:add, value})
    end

    def get(ref) do
        GenServer.call(__MODULE__, {:get, ref})
    end

    def show_state do
        GenServer.cast(__MODULE__, :state)
    end

    def ack(ref) do
        send self(), {:ack, ref}
    end
end