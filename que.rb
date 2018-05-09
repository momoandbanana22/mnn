# Que class
class Que
  public def initialize
    @lock = Mutex.new
    @que = [] # empty array
  end
  # take top item
  public def peek
    return(nil) if @que.empty?
    @lock.synchronize do
      return @que[0]
    end
  end
  # take top item with wait
  public def peek_wait
    loop do
      redo if @que.empty?
      @lock.synchronize do
        return @que[0]
      end
    end
  end
  # add item
  public def push(item)
    @lock.synchronize do
      @que.push(item)
    end
  end
  # del item
  public def shift
    @lock.synchronize do
      @que.shift
    end
  end
end

# ResQue class
class ResQue < Que
  public def take_res(objid)
    loop do
      ret = nil
      @lock.synchronize { ret = @que.select { |res| res[:objid] == objid } }
      redo if ret.empty?
      @lock.synchronize { @que.reject! { |res| res[:objid] == objid } }
      return ret[0] # return ret[0]
    end
  end
end
