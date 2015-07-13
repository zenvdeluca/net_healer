#MISC methods - might be deprecated in a future.
class TOOLS
  def ipverify(str)                                         # validate IPv4 / IPv6 regexp, and resolve IP
    case str
    when Resolv::IPv4::Regex
      return str
    when Resolv::IPv6::Regex
      return str
    else
      begin
        resolved = Resolv.getaddress(str)
      rescue
        puts "Failed to resolve #{str}"
        return -1
      end
      return resolved
    end
  end
end
