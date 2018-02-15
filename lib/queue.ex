defmodule PerQ.Queue do
    use GenServer
    require Record

    Record.defrecord :q_change, [timestamp: nil, operation_num: nil, operation: nil]
    @tab :history

    def start_link() do
        GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    def init(_opts) do
        :ets.new(@tab, [:bag, :protected, :named_table, {:keypos, q_change(:timestamp)}])
        {:ok, %{:stack => [], :operation_num => 0, :await_acks => []}}
    end

    #################### Call ####################
    def handle_call(:stack, _from, state) do
        current_stack = Map.get(state, :stack)
        {:reply, {:ok, current_stack}, state}
    end
    def handle_call({:revert, time, num}, _from, state) do
#        ms = case num == :undefined do
#            true -> [{{:'_',:'$1',:'_',:'$3'}, [{:>,:'$1',time}], [:'$3']}]
#            false -> [{{:'_',:'$1',:'$2',:'$3'}, [{:>,:'$1',time}, {:>,:'$2',num}], [:'$3']}]
#        end
        ms = [{{:'_',:'$1',:'_',:'$3'}, [{:>,:'$1',time}], [:'$3']}]
        selection = :ets.select(@tab, ms)

        IO.inspect(selection)

        current_stack = Map.get(state, :stack)
        reverted_stack = handle_revertion(selection, current_stack)

        {:reply, {:ok, reverted_stack}, state}
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

        {:ok, tref} = :timer.send_after(15000, {:reject, ref})

        IO.puts("add timer")
        IO.inspect(tref)

        {:reply, {:ok, h, timestamp, new_operation_num}, Map.put(state, :stack, :lists.reverse(t))
            |> Map.put(:operation_num, new_operation_num)
            |> Map.put(:await_acks, [{ref, tref, h, timestamp, new_operation_num}|current_awaits])}
    end
    def handle_call(_msg, _from, state) do
        {:reply, :ok, state}
    end

    #################### Cast ####################
    def handle_cast(:state, state) do

        IO.inspect(state)

        {:noreply, state}
    end
    def handle_cast(:clear, _state) do
        :ets.delete_all_objects(@tab)
        {:noreply, %{:stack => [], :operation_num => 0, :await_acks => []}}
    end
    def handle_cast(_msg, state) do
        {:noreply, state}
    end

    #################### Info ####################
    def handle_info({:reject, ref}, state) do

        IO.puts("timeout")
        IO.inspect(ref)

        current_stack = Map.get(state, :stack)
        current_awaits = Map.get(state, :await_acks)
        current_operation_num = Map.get(state, :operation_num)
        state1 = case List.keytake(current_awaits, ref, 0) do
            {{_ref, tref, value, _timestamp, _new_operation_num}, new_awaits} ->

                IO.puts("timer to cancel reject")
                IO.inspect(tref)

                test = :timer.cancel(tref)

                IO.inspect(test)

                reject_timestamp = :erlang.system_time(:millisecond)
                reject_operation_num = current_operation_num + 1
                reject_change = q_change(timestamp: reject_timestamp, operation_num: reject_operation_num, operation: {:reject, value})
                :ets.insert(@tab, reject_change)

                Map.put(state, :stack, [value|current_stack])
                |> Map.put(:await_acks, new_awaits)
            _ ->
                state
        end
        {:noreply, state1}
    end
    def handle_info({:ack, ref}, state) do

        IO.puts("ack")
        IO.inspect(ref)

        current_awaits = Map.get(state, :await_acks)
        state1 = case List.keytake(current_awaits, ref, 0) do
            {{_ref, tref, value, timestamp, new_operation_num}, new_awaits} ->

                IO.puts("timer to cancel ack")
                IO.inspect(tref)

                test = :timer.cancel(tref)

                IO.inspect(test)

                new_change = q_change(timestamp: timestamp, operation_num: new_operation_num, operation: {:get, value})
                :ets.insert(@tab, new_change)

                Map.put(state, :await_acks, new_awaits)
            _ ->

                IO.puts("some wrong ack")

                state
        end
        {:noreply, state1}
    end
    def handle_info(_msg, state) do

        IO.inspect(_msg)

        {:noreply, state}
    end

    #################### External functions ####################
    def add(value) do
        GenServer.call(__MODULE__, {:add, value})
    end

    def get(ref) do
        GenServer.call(__MODULE__, {:get, ref})
    end

    def stack() do
        GenServer.call(__MODULE__, :stack)
    end

    def show_state() do
        GenServer.cast(__MODULE__, :state)
    end

    def ack(ref) do
        Process.send(__MODULE__, {:ack, ref}, [])
    end

    def reject(ref) do
        Process.send(__MODULE__, {:reject, ref}, [])
    end

    def revert(timestamp) do
        GenServer.call(__MODULE__, {:revert, timestamp, :undefined})
    end
#    def revert(timestamp, num) do
#        GenServer.call(__MODULE__, {:revert, timestamp, num})
#    end

    def clear() do
        GenServer.cast(__MODULE__, :clear)
    end

    #################### Internal function ####################
    def handle_revertion(operations, stack) do
        test = List.foldr(operations, stack, fn(operation, s) ->
            invert(operation, s)
        end)

        IO.inspect(test)

        test
    end

    def invert({:reject, value}, stack) do
        [value|t] = stack
        t ++ [value]
    end
    def invert({:get, value}, stack) do
        stack ++ [value]
    end
    def invert({:add, _value}, stack) do
        [_|t] = stack
        t
    end
end