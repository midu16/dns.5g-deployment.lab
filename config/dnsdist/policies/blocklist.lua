-- Blocklist lab policy: NXDOMAIN for configured suffixes.

blockedSuffixes = {
  "malware.test.",
  "blocked.lab."
}

for _, suffix in ipairs(blockedSuffixes) do
  addAction(QNameSuffixRule(suffix), RCodeAction(DNSRCode.NXDOMAIN))
end
