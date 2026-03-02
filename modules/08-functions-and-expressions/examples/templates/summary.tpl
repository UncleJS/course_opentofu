Service Summary
===============
Total services : ${length(services)}
Ports in use   : ${join(", ", all_ports)}

Services (alphabetical):
%{ for name in service_names ~}
  - ${name}
%{ endfor ~}

Addresses:
%{ for key, addr in service_addresses ~}
  ${key} => ${addr}
%{ endfor ~}

Details:
%{ for key, svc in services ~}
[${key}]
  name        : ${svc.name}
  port        : ${svc.port}
  protocol    : ${svc.protocol}
  environment : ${svc.environment}
%{ if length(svc.tags) > 0 ~}
  tags:
%{ for tk, tv in svc.tags ~}
    ${tk} = ${tv}
%{ endfor ~}
%{ endif ~}

%{ endfor ~}
