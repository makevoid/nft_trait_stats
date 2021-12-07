# monkeypatches

class Hash
  alias_method :f, :fetch
end

class FalseClass
  def empty?
    false
  end
end
