defmodule PerQTest do
    use ExUnit.Case
    doctest PerQ

    test "add 1" do
        PerQ.Queue.clear()

        assert {:ok, timestamp, operation_num} = PerQ.Queue.add(1)
        assert is_integer(timestamp) == true
        assert operation_num == 1
    end

    test "add 1,2,3; get 1, ack" do
        PerQ.Queue.clear()

        PerQ.Queue.add(1)
        PerQ.Queue.add(2)
        PerQ.Queue.add(3)
        assert {:ok, 1, _timestamp, operation_num} = PerQ.Queue.get("some_ref")
        assert operation_num == 4
        PerQ.Queue.ack("some_ref")
        assert {:ok, [3,2]} = PerQ.Queue.stack()
    end

    test "add 1,2,3; get 1, reject" do
        PerQ.Queue.clear()

        PerQ.Queue.add(1)
        PerQ.Queue.add(2)
        PerQ.Queue.add(3)
        assert {:ok, 1, _timestamp, operation_num} = PerQ.Queue.get("some_ref1")
        assert operation_num == 4
        PerQ.Queue.reject("some_ref1")
        assert {:ok, [1,3,2]} = PerQ.Queue.stack()
    end

    test "add 1,2,3; get 1, ack, add 4,5,6; revert to add 3" do
        PerQ.Queue.clear()

        PerQ.Queue.add(1)
        PerQ.Queue.add(2)
        {:ok, timestamp, _} = PerQ.Queue.add(3)

        :timer.sleep(1000)

        PerQ.Queue.get("some_ref2")
        PerQ.Queue.ack("some_ref2")
        assert {:ok, [3,2]} = PerQ.Queue.stack()
        PerQ.Queue.add(4)
        PerQ.Queue.add(5)
        PerQ.Queue.add(6)
        assert {:ok, [3,2,1]} = PerQ.Queue.revert(timestamp)
    end
end
