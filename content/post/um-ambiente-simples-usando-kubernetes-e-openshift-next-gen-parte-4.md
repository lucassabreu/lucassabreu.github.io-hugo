+++
toc = false
draft = false
date = "2017-03-10"
title = "Um ambiente simples usando Kubernetes e OpenShift Next Gen - Parte 4"
description = "Para completar a jornada vamos ver como o Kubernetes lida com dados sensíveis dentro da plataforma"
images = ["/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/header.png"]
tags = ["Kubernetes","Openshift","Introduction","Simple","Docker"]

prev = "/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-3/"

+++

<!--more-->

{{< figure class="big" src="/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/header.png" >}}

Este post é a quarta parte de uma série sobre o básico necessário para usar o Kubernetes, caso você não tenha lido o post anterior recomendo lê-lo e depois voltar aqui para não ficar perdido.

-   Parte 1 - Conceitos Básicos: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1)
-   Parte 2 - Construindo o Ambiente: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-2)
-   Parte 3 - Volumes Persistentes: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-3)

* * *

Como citei no [post anterior](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-3) ainda existe um ponto de desconforto no ambiente, que é o fato das senhas e usuários estarem expostos diretamente nas configurações. O Kubernetes oferece uma solução para esse problema os [**Secrets**](https://kubernetes.io/docs/user-guide/secrets/).

E agora irei mostrar como adicioná-los ao projeto.

Caso não tenha mais os fontes até o estado do post anterior, ou prefira acompanhar o meu andamento, pode pode pegá-los aqui: <https://github.com/lucassabreu/openshift-next-gen/tree/v2>; ou executar:

```shell
git clone -b v2 \
    https://github.com/lucassabreu/openshift-next-gen.git
```

* * *

#### Secrets

Existem algumas formas de criar e usar os mesmos, criá-los diretamente de arquivos, ou usando configurações, e expô-los aos contêineres usando volumes ou variáveis de ambiente.

Para essa aplicação vou utilizar um YAML para definir um Secret e vou modificar os Pods para alimentarem as variáveis de ambiente com eles. A estrutura básica do Secret é como segue:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secrets
type: Opaque
data:
  mysql-root-password: <hash base64>
  mysql-user: <hash base64>
  mysql-password: <hash base64>
  mysql-database-connection: <hash base64>
```

Nele estou criando o Secret `mysql-secrets` e definindo quatro chaves que representam as três variáveis do MySQL e uma do servidor HTTP. No lugar do `<hash base64>` deve ir o conteúdo do segredo em Base 64, que pode ser gerado usando o comando `echo -n "meusegredo" | base64 -w0`.

Eu não gostei muito da ideia de guardar o Base 64 dentro da definição do Secret, então fiz a seguinte modificação no meu `mysql-secrets.yml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secrets
type: Opaque
data:
  mysql-root-password: %MYSQL_ROOT_PASSWORD
  mysql-user: %MYSQL_USER
  mysql-password: %MYSQL_PASSWORD
  mysql-database-connection: %DATABASE_CONNECTION
```

E quando vou aplicar o Secret no Kubernetes uso este script:

```bash
MYSQL_ROOT_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32})
B64_MYSQL_ROOT_PASSWORD=$(echo -n $MYSQL_ROOT_PASSWORD | base64 -w0)
B64_DATABASE_USER=$(echo -n $DATABASE_USER | base64 -w0)
B64_DATABASE_PASSWORD=$(echo -n $DATABASE_PASSWORD | base64 -w0)
B64_DATABASE_CONNECTION=$(echo -n \
    "mysql://$DATABASE_USER:$DATABASE_PASSWORD@db-service:3306/appointments" \
    | base64 -w0)

sed "\
  s|%MYSQL_ROOT_PASSWORD|$B64_MYSQL_ROOT_PASSWORD|;\
  s|%MYSQL_USER|$B64_DATABASE_USER|;\
  s|%MYSQL_PASSWORD|$B64_DATABASE_PASSWORD|;\
  s|%DATABASE_CONNECTION|$B64_DATABASE_CONNECTION|" \
  mysql-secrets.yml | oc apply -f -
```

Esse script cria uma senha aleatória para o root e usa duas variáveis de ambiente para definir o usuário e senha do MySQL, faz o Base 64 deles, injeta eles no arquivo via `sed` no Secret e aplica no Kubernetes com `oc apply -f -` que irá ler a saída do `sed` e aplicá-la. Na hora de executar fica assim:

```shell
$ export DATABASE_USER=appoint
$ export DATABASE_PASSWORD=123
$ ./env-set-oc.sh
secret "mysql-secrets" configured
```

Altero os Deployments para considerarem o Secret que criei:

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: "db-deployment"
spec:
  replicas: 1
  template:
    metadata:
      labels:
        name: "db-pod"
    spec:
      containers:
        - name: "db"
          image: "lucassabreu/openshift-mysql-test"
          ports:
            - name: "mysql-port"
              containerPort: 3306
          env:
            - name: MYSQL_DATABASE
              value: appointments
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secrets
                  key: mysql-root-password
            - name: MYSQL_USER
              valueFrom:
                secretKeyRef:
                  name: mysql-secrets
                  key: mysql-user
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secrets
                  key: mysql-password
          volumeMounts:
            - name: "mysql-persistent-volume"
              mountPath: "/var/lib/mysql"
      volumes:
        - name: "mysql-persistent-volume"
          persistentVolumeClaim:
            claimName: mysql-pv-claim
```
<small><center>db-deployment.yml</center></small>

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: "node-deployment"
spec:
  replicas: 1
  template:
    metadata:
      labels:
        name: "node-pod"
    spec:
      containers:
        - name: "node"
          image: "lucassabreu/openshift-app-test"
          ports:
            - name: node-port
              containerPort: 8080
              protocol: TCP
          env:
            - name: DATABASE_CONNECTION
              valueFrom:
                secretKeyRef:
                  name: mysql-secrets
                  key: mysql-database-connection
```
<small><center>node-deployment.yml</center></small>

A alteração consiste de trocar a chave `value` das variáveis por `valueFrom` e apontar para as chaves corretas dentro do Secret.

Depois que aplica as mudanças os Deployments vão identificá-las e trocar os Pods por novos. E passaram a utilizar os Secrets informado nas variáveis para eles.

* * *

Ao final dessa séria, a conclusão que posso chegar é que o Kubernetes exige um conjunto razoavelmente grande de configurações para podermos servir uma aplicação, mas são arquivos simples de se entender e muito bem [documentados](https://kubernetes.io/docs/reference/) o que facilitou bastante o processo, e não me fez sentir o peso dessa quantidade.
