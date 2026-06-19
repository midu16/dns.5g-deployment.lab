-- Internal recursive_net clients vs other lab subnets.
addAction(
  AndRule{
    NetmaskGroupRule({"10.89.3.0/24"}),
    QNameRule("split-horizon.test.")
  },
  SpoofAction("10.89.3.88")
)

addAction(
  AndRule{
    NotRule(NetmaskGroupRule({"10.89.3.0/24"})),
    QNameRule("split-horizon.test.")
  },
  SpoofAction("203.0.113.88")
)
