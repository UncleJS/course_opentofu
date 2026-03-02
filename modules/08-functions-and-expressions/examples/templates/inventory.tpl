[all]
%{ for key, svc in services ~}
${svc.name} ansible_host=localhost ansible_port=${svc.port} protocol=${svc.protocol}
%{ endfor ~}

[by_environment]
%{ for key, svc in services ~}
${svc.name} environment=${svc.environment}
%{ endfor ~}
