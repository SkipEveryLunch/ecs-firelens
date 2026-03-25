output "dns_name" {
  value = aws_lb.main.dns_name
}

// 東京リージョンのALBゾーンID（固定値）
output "zone_id" {
  value = "Z14GRHDCWA56QT"
}
