module Puppet::Parser::Functions
  newfunction(:sort_hash_by_key) do |args|
    my_hash = args[0]
    recursive = args[1]

    my_hash.keys.sort().reduce({}) do |seed, key|
      seed[key] = my_hash[key]
      if recursive && seed[key].is_a?(Hash)
        seed[key] = sort_hash_by_key(seed[key], true)
      end
    end
    seed
  end
end
