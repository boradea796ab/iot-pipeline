resource "local_file" "sim_cert_pem" {
  filename = "${var.certs_output_dir}/device_certificate.pem"
  content  = aws_iot_certificate.sim_meter_cert.certificate_pem
}

resource "local_file" "sim_private_key" {
  filename = "${var.certs_output_dir}/private_key.pem"
  content  = aws_iot_certificate.sim_meter_cert.private_key
}

resource "local_file" "sim_public_key" {
  filename = "${var.certs_output_dir}/public_key.pem"
  content  = aws_iot_certificate.sim_meter_cert.public_key
}
