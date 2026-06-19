-- Per-subnet rate limit (lab defaults).

addAction(
  NetmaskGroupRule({"10.89.0.0/16"}),
  MaxQPSRule(500)
)

addAction(
  NetmaskGroupRule({"192.168.200.0/24"}),
  MaxQPSRule(50)
)
