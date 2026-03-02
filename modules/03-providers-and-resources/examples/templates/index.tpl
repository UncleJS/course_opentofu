Environment Index
=================
%{ for env, desc in environments ~}
[${env}]
  Description : ${desc}
  Codename    : ${pet_names[env]}
  Config file : ${files[env]}

%{ endfor ~}
