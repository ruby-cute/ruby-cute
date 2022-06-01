module Cute
   module Synchronization
     class Semaphore
      def initialize(max)
        @lock = Mutex.new
        @cond = ConditionVariable.new
        @used = 0
        @max = max
      end

      def acquire(n = 1)
        @lock.synchronize {
          while (n > (@max - @used)) do
            @cond.wait(@lock)
          end
          @used += n
        }
      end

      def relaxed_acquire(n = 1)
        taken = 0
        @lock.synchronize {
          while (@max == @used) do
            @cond.wait(@lock)
          end
          taken = (n + @used) > @max ? @max - @used : n
          @used += taken
        }
        return n - taken
      end

      def release(n = 1)
        @lock.synchronize {
          @used -= n
          @cond.broadcast
        }
      end
    end

    class SlidingWindow
      def initialize(size)
        @queue = []
        @lock = Mutex.new
        @finished = false
        @size = size
      end

      def add(t)
        @queue << t
      end

      def run
        tids = []
        (1..@size).each {
          tids << Thread.new {
            while !@finished do
              task = nil
              @lock.synchronize {
                if @queue.size > 0
                  task = @queue.pop
                else
                  @finished = true
                end
              }
              if task
                if task.is_a?(Proc)
                  task.call
                else
                  system(task)
                end
              end
            end
          }
        }
        tids.each { |tid| tid.join }
      end
    end
  end
end

if (__FILE__ == $0)
  w = Cute::Synchronization::SlidingWindow.new(3)
  (1..10).each {
    w.add("sleep 1")
  }
  w.run
end
