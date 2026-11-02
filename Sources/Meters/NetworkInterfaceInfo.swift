import Darwin
import SystemConfiguration

/// What the network menu says about an interface besides its traffic: its name, addresses and
/// hardware address. Read when the menu opens, never on the tick.
public struct NetworkInterfaceInfo: Sendable, Equatable {
    /// The BSD name, such as `en0`.
    public var name: String
    /// The name System Settings shows, such as "Wi-Fi"; nil for an interface it doesn't list.
    public var displayName: String?
    public var ipv4Addresses: [String] = []
    /// Addresses other than link-local ones, which every interface has.
    public var ipv6Addresses: [String] = []
    /// The MAC address, `aa:bb:cc:dd:ee:ff`; nil for an interface without one.
    public var macAddress: String?

    /// Every interface with a routable address, keyed by interface index.
    public static func current() -> [Int: NetworkInterfaceInfo] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else {
            preconditionFailure("getifaddrs failed: \(String(cString: strerror(errno)))")
        }
        defer { freeifaddrs(first) }
        let displayNames = Self.displayNames()
        var byName: [String: NetworkInterfaceInfo] = [:]
        var cursor = first
        while let entry = cursor?.pointee {
            cursor = entry.ifa_next
            guard let address = entry.ifa_addr else { continue }
            let name = String(cString: entry.ifa_name)
            var info =
                byName[name] ?? NetworkInterfaceInfo(name: name, displayName: displayNames[name])
            switch Int32(address.pointee.sa_family) {
            case AF_INET:
                info.ipv4Addresses.append(numericHost(address))
            case AF_INET6:
                let host = numericHost(address)
                if !host.hasPrefix("fe80:") { info.ipv6Addresses.append(host) }
            case AF_LINK:
                info.macAddress = macAddress(address)
            default:
                break
            }
            byName[name] = info
        }
        var byIndex: [Int: NetworkInterfaceInfo] = [:]
        for info in byName.values where !(info.ipv4Addresses.isEmpty && info.ipv6Addresses.isEmpty)
        {
            let index = Int(if_nametoindex(info.name))
            if index > 0 { byIndex[index] = info }
        }
        return byIndex
    }

    private static func numericHost(_ address: UnsafeMutablePointer<sockaddr>) -> String {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0,
            NI_NUMERICHOST)
        precondition(result == 0, "getnameinfo failed: \(String(cString: gai_strerror(result)))")
        // A scoped IPv6 address ends in %interface, which the menu already names.
        let text = String(
            decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return text.split(separator: "%").first.map(String.init) ?? text
    }

    private static func macAddress(_ address: UnsafeMutablePointer<sockaddr>) -> String? {
        address.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { link in
            guard link.pointee.sdl_alen == 6,
                let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data)
            else { return nil }
            // sdl_data holds the name and then the address. A long name runs past the array
            // Swift declares, so the bytes are read through the raw pointer, within sdl_len.
            let start = UnsafeRawPointer(link) + dataOffset + Int(link.pointee.sdl_nlen)
            return (0..<6).map {
                String(format: "%02x", start.load(fromByteOffset: $0, as: UInt8.self))
            }
            .joined(separator: ":")
        }
    }

    /// System Settings' name for each BSD name.
    private static func displayNames() -> [String: String] {
        guard let all = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }
        var names: [String: String] = [:]
        for interface in all {
            if let bsd = SCNetworkInterfaceGetBSDName(interface) as String?,
                let display = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?
            {
                names[bsd] = display
            }
        }
        return names
    }
}
