+++
title = "Ambientes por Branch com OpenShift Next Gen usando GitHub"
tags = ["Openshift","Continuous Integration","Continuous Deployment","Github","Buddy Works"]
toc = false
draft = false
description = "Esta postagem é uma continuação da \"Ambientes por Branch com OpenShift Next Gen\", implementando o processo no GitHub usando Buddy.Works e o OpenShift da GetUp Cloud"
images = ["/post/ambientes-por-branch-com-openshift-next-gen-usando-github/header.png"]
date = "2017-05-07"

+++

<!--more-->

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen-usando-github/header.png" >}}

<i>Esta postagem é uma continuação da [**Ambientes por Branch com OpenShift Next Gen**](/post/ambientes-por-branch-com-openshift-next-gen), a introdução do problema esta lá e também mostro como implementar o processo de deploy usando o GitLab nele, se não viu da uma conferida, vale o investimento* 😉.</i>

Como prometi na outra postagem, vamos criar um processo de deploy de ambientes por branch usando o [GitHub](https://medium.com/@github).

No caso do GitHub, ele cobre "apenas" a parte de repositório de fontes, ele em si não tem integração direta com o Kubernetes/OpenShift, mas possui uma grande gama de opções no que diz respeito de ferramentas de CI e CD.

A implementação que vou demonstrar usará o [Buddy](https://medium.com/@BuddyWorks), mas pode ser replicada para qualquer outro CI, com dificuldade semelhante. Para o registro de imagens irei usar o [Docker Hub](http://hub.docker.com) e novamente o OpenShift da [Getup Cloud](https://medium.com/@getupcloud).

Sobre uma introdução ao Kubernetes/OpenShift pode ver aqui:

[**Um ambiente simples usando Kubernetes e OpenShift Next Gen — Parte 1**](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/)

O cliente de linha de comando do OpenShift pode ser baixado em:

[**openshift/origin** origin - Enterprise Kubernetes for Developers](https://github.com/openshift/origin/releases)

* * *

O que queremos montar é um ambiente por branch/PR que deve ser facilmente criado e destruído. Para demonstrar criei um repositório no GitHub com uma aplicação bem simples que apenas retorna uma página estática, mas é o suficiente para o objetivo.

{{< figure src="/post/ambientes-por-branch-com-openshift-next-gen-usando-github/helloworld.png"
        title="retorno do serviço helloworld" >}}

E configurei o Buddy para construir uma imagem com base nesse repositório e publicar ela como [lucassabreu/k8s-pr-envs](https://hub.docker.com/r/lucassabreu/k8s-pr-envs/) no Docker Hub.

Nesse momento o arquivo `buddy.yml` esta assim:

```yaml
- pipeline: "Build"
  trigger_mode: "ON_EVERY_PUSH"
  ref_name: "master"
  actions:
  - action: "Build Docker image"
    type: "DOCKERFILE"
    login: "${DOCKER_HUB_USER}"
    password: "${DOCKER_HUB_PASSWORD}"
    docker_image_tag: "${execution.to_revision.revision}"
    dockerfile_path: "Dockerfile"
    repository: "lucassabreu/k8s-pr-envs"
```
<p class="code-legend">buddy.yml</p>

O fonte nesse momento pode ser visto em:

[**lucassabreu/k8s-pr-envs** v1](https://github.com/lucassabreu/k8s-pr-envs/tree/v1)

* * *

Nesse primeiro momento não possuímos nenhum processo de deploy, seja de teste, produção ou por branch.

Então vamos adicionar um processo de deploy no OpenShift para o ambiente de produção e testes, sendo que o ambiente de testes é atualizado automaticamente para os commits na master e o de produção apenas quando um usuário disparar o deploy via interface web do Buddy (<http://app.buddy.works/>).

Precisamos preparar o OpenShift para montar esse processo, primeiramente criamos um **Namespace**. A forma como criamos um varia de vendor para vendor, no caso do OpenShift da [Getup Cloud](https://medium.com/@getupcloud), basta ir em <https://portal.getupcloud.com/projects> e criar um novo projeto, o nome do projeto será o **Namespace.**

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen-usando-github/getup-dashboard.png" >}}

Tendo um **Namespace** precisamos de uma forma do Buddy se autenticar contra o OpenShift, para isso podemos criar um ServiceAccount e usar o **Token** do mesmo para isso. O script abaixo mostra como criar uma ServiceAccount e resgatar o **Token** usando o CLI do OpenShift:

<pre>
<b>$ oc login https://api.getupcloud.com:443</b>
Authentication required for https://api.getupcloud.com:443 ...
Username: lucas.s.abreu@gmail.com
Password:
Login successful.
...

<b>$ oc project github-k8s-pr-envs #usar o seu projeto</b>
Now using project "github-k8s-pr-envs" on server ...

<b>$ oc create serviceaccount github</b>
serviceaccount "github" created

<b>$ oc policy add-role-to-user admin \
    system:serviceaccount:github-k8s-pr-envs:github</b>

<b>$ oc describe serviceaccount github</b>
Name:  github
Namespace: github-k8s-pr-envs
Labels:  <none>

Image pull secrets: github-dockercfg-vat7r

Mountable secrets:  github-token-d3u3t
                    github-dockercfg-vat7r

Tokens:             github-token-2pimz
                    github-token-d3u3t

<b>$ oc describe secret github-token-d3u3t</b>
Name:  github-token-d3u3t
Namespace: github-k8s-pr-envs
Labels:  <none>
Annotations: kubernetes.io/service-account.name=github
  kubernetes.io/service-account.uid=zzz

Type: kubernetes.io/service-account-token

Data
====
ca.crt:  1066 bytes
namespace: 18 bytes
service-ca.crt: 2182 bytes
token:  <i>token-do-openshift-que-estou-ocultando</i>
</pre>

Agora podemos informar no Buddy algumas variáveis para ele disponibilizar para nós depois. Meu painel ficou como abaixo:

{{< figure src="/post/ambientes-por-branch-com-openshift-next-gen-usando-github/buddy-envs.png"
    title="buddy environments" >}}


A URL da API e o domínio que o OpenShift irá utilizar também dependem do seu vendor, no meu caso a API está em `https://api.getupcould.com:443` e o domínio base é `getup.io`.

Agora podemos criar os novos pipelines no Buddy. No `buddy.yml` as linhas abaixo:

```yaml
- pipeline: "Deploy Staging"
  trigger_mode: "ON_EVERY_PUSH"
  ref_name: "master"
  actions:
  - action: "Deploy Master to Staging"
    type: "BUILD"
    docker_image_name: "lucassabreu/openshift-k8s-cli"
    docker_image_tag: "latest"
    execute_commands:
    - TAG="${execution.to_revision.revision}"
      ENV=staging
      OPENSHIFT_NAMESPACE="${OPENSHIFT_NAMESPACE}"
      OPENSHIFT_API_URL="${OPENSHIFT_API_URL}"
      OPENSHIFT_TOKEN="${OPENSHIFT_TOKEN}"
      OPENSHIFT_DOMAIN="${OPENSHIFT_DOMAIN}"
      ./k8s/deploy
- pipeline: "Deploy Production"
  trigger_mode: "MANUAL"
  ref_name: "master"
  actions:
  - action: "Deploy Master to Production"
    type: "BUILD"
    docker_image_name: "lucassabreu/openshift-k8s-cli"
    docker_image_tag: "latest"
    execute_commands:
    - TAG="${execution.to_revision.revision}"
      ENV=production
      OPENSHIFT_NAMESPACE="${OPENSHIFT_NAMESPACE}"
      OPENSHIFT_API_URL="${OPENSHIFT_API_URL}"
      OPENSHIFT_TOKEN="${OPENSHIFT_TOKEN}"
      OPENSHIFT_DOMAIN="${OPENSHIFT_DOMAIN}"
      ./k8s/deploy
```
<p class="code-legend">buddy.yml (v2)</p>

Basicamente criei duas novas pipelines, uma chamada `Deploy Staging` e outra `Deploy Production` as únicas diferenças entre elas é que a `Deploy Staging` é automática para todo o commit na master e usa `ENV=staging` para indicar o ambiente; e `Deploy Production` é manual e usa `ENV=production`. Também criei variáveis para injetar os valores que informamos antes no Buddy e uma extra `COMMIT` para que ele consiga identificar qual imagem deve usar.

Essas duas pipelines basicamente chamam o script abaixo:

```bash
#!/bin/bash

echo ">> Connecting to OpenShift..."
oc login "$OPENSHIFT_API_URL" --token "$OPENSHIFT_TOKEN"
oc project "$OPENSHIFT_NAMESPACE"

echo ">> Removing old application..."
oc delete all -l "app=$ENV"

IMAGE_TAG="lucassabreu/k8s-pr-envs:$TAG"
HOSTNAME="$OPENSHIFT_NAMESPACE-$ENV.$OPENSHIFT_DOMAIN"

if [ "$ENV" = "production" ]; then
    HOSTNAME=$OPENSHIFT_NAMESPACE.$OPENSHIFT_DOMAIN
fi

echo ">> Deploying application..."
sed "
    s|__ENV__|$ENV|;
    s|__IMAGE_TAG__|$IMAGE_TAG|;
    s|__HOSTNAME__|$HOSTNAME|;
    " k8s/full.yml | oc apply -f -

echo "Enviroment $ENV deployed to: http://$HOSTNAME/"
```
<p class="code-legend">k8s/deploy</p>

Este script basicamente se autentica contra a API do OpenShift usando o Token que criamos antes, destrói a aplicação antiga e executa o deploy
de uma nova.

Para poder identificar quais os componentes de cada ambiente estou marcando eles com a label `app=$ENV`, dessa forma todos os componentes do ambiente `staging` estão marcados com `app=staging` e fica fácil eliminá-los e identificá-los.

É importante ressaltar que estou usando uma imagem customizada para rodar esses comandos (`lucassabreu/openshift-k8s-cli`) que basicamente é um `ubuntu` com o `oc` instalado dentro dela.

Também estou usando um truque de "*templating*" com o YAML que define os ambientes para poder inserir as variáveis de cada ambiente nele. Existem outras ferramentas mais avançadas como o [Helm](https://github.com/kubernetes/helm), mas para o meu exemplo templating com `sed` é o suficiente.

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: hw-dpl-__ENV__
  labels:
    app: __ENV__
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: __ENV__
        name: hw-pod
    spec:
      containers:
      - name: hw-container
        image: __IMAGE_TAG__
        imagePullPolicy: Always
        ports:
        - name: web-port
          containerPort: 8080
---
apiVersion: "v1"
kind: Service
metadata:
  name: hw-src-__ENV__
  labels:
    app: __ENV__
spec:
  ports:
    - port: 80
      targetPort: "web-port"
      protocol: TCP
  selector:
    name: hw-pod
    app: __ENV__
---
apiVersion: v1
kind: Route
metadata:
  name: __ENV__
  labels:
    app: __ENV__
spec:
  host: __HOSTNAME__
  to:
    kind: Service
    name: hw-src-__ENV__
```
<p class="code-legend">k8s/full.yml</p>

Agora toda vez que é feito commit na master o ambiente de *staging* é automaticamente atualizado, e ficou bem simples atualizar o ambiente *production*.

Fonte até agora:

[**lucassabreu/k8s-pr-envs** v2](https://github.com/lucassabreu/k8s-pr-envs/tree/v2)

* * *

Agora que temos um processo de *build* e um de *deploy automatizado*, vamos adicionar a função de deploy por branch.

Basicamente precisamos de duas novas etapas no nosso CI, uma para subir o ambiente para uma branch e outro para destruir esse ambiente.

Primeiro vamos preparar o deploy por branch, para isso adicionei as seguintes linhas do `buddy.yml`:

```yaml
- pipeline: "Review"
  trigger_mode: "ON_EVERY_PUSH"
  ref_name: "((?!master).*)"
  actions:
  - action: "Build Docker image"
    type: "DOCKERFILE"
    login: "${DOCKER_HUB_USER}"
    password: "${DOCKER_HUB_PASSWORD}"
    docker_image_tag: "${execution.branch.name}"
    dockerfile_path: "Dockerfile"
    repository: "lucassabreu/k8s-pr-envs"
  - action: "Deploy By Branch"
    type: "BUILD"
    docker_image_name: "lucassabreu/openshift-k8s-cli"
    docker_image_tag: "latest"
    execute_commands:
    - TAG="${execution.branch.name}"
      ENV="${execution.branch.name}"
      GITHUB_TOKEN="${GITHUB_TOKEN}"
      LOG_URL="${execution.html_url}"
      OPENSHIFT_NAMESPACE="${OPENSHIFT_NAMESPACE}"
      OPENSHIFT_API_URL="${OPENSHIFT_API_URL}"
      OPENSHIFT_TOKEN="${OPENSHIFT_TOKEN}"
      OPENSHIFT_DOMAIN="${OPENSHIFT_DOMAIN}"
      ./k8s/deploy
```

No novo pipeline *Review* temos um *build* da imagem e um deploy de um ambiente para a branch em questão, para uma rota própria.

Eu acabei juntando essas duas ações, pois o build que roda na master vai versionando as imagens por commit, que é uma prática comum e que ajudaria a fazer o deploy para produção mais simples, porém branchs de desenvolvimento tendem a ser mais caóticas e iriam poluir muito o registro de imagens (se usar o do AWS seria um custo maior também), então preferi manter uma imagem por branch, até para não confundir também.

Se eu criar uma nova branch nesse momento, o Buddy automaticamente irá montar uma imagem para ela e inseri-la no OpenShift, se o nome da branch for `a-change` o nome do ambiente <http://github-k8s-pr-envs-a-change.getup.io> (talvez ainda esteja acessível).

Eu sei disso porque eu escrevi o script, eu poderia documentar isso no projeto para todos saberem como descobrir as URLs corretas, mas é mais do que natural esperar erros por esse caminho, um "o" que vira "a" na hora de digitar, um nome de branch estranho, etc.

Dessa forma fica difícil para a equipe de QA acessar aos ambientes por branch toda a vez correndo o risco de errar. Então fiz algumas alterações no `k8s/deploy` para utilizar a [API de Deployments do GitHub](https://developer.github.com/v3/repos/deployments/) para registrar as URLs diretamente nos commits.

```shell
if [ ! -z $GITHUB_TOKEN ] && [ "$ENV" != "production" ] && [ "$ENV" != "staging" ]; then
    echo ">> Registering $ENV deployment..."

    ID_DEPLOYMENT=$(k8s/github-deployment "lucassabreu/k8s-pr-envs" "$GITHUB_TOKEN" create \
        "$ENV" "$ENV" true | jq ".id")
    RETURN=$(k8s/github-deployment "lucassabreu/k8s-pr-envs" "$GITHUB_TOKEN" status set \
        "$ID_DEPLOYMENT" success "http://$HOSTNAME/" "$LOG_URL")
    if [ "$(echo $RETURN | jq ".message")" != "null" ]; then
        echo $RETURN
        exit 1
    fi
fi

echo "Enviroment $ENV deployed to: http://$HOSTNAME/"
```
<p class="code-legend">deploy.sh</p>

Com isso faço algumas chamadas a API do GitHub usando o `k8s/github-deployment` (que é basicamente um facilitador para a API) e consigo registrar o deploy no GitHub.

O Pull Request da branch `a-change` fica assim:

{{< figure src="/post/ambientes-por-branch-com-openshift-next-gen-usando-github/github-deployments.png" >}}

Nesse botão "View deployment" está o link para a rota que criamos no deploy, e dessa forma fica extremamente fácil para a equipe de QA acessar os ambientes.

Fontes até agora:

[**lucassabreu/k8s-pr-envs** v3.1](https://github.com/lucassabreu/k8s-pr-envs/tree/v3.1)

* * *

Ainda fica faltando uma última atividade por realizar, que é destruir o ambiente da branch quando os Testers não mais precisarem deles.

Então vamos adicionar uma nova pipeline no `buddy.yml`:

```yaml
- pipeline: "Close Review"
  trigger_mode: "MANUAL"
  ref_name: "((?!master).*)"
  actions:
  - action: "Destroy Branch Environment"
    type: "BUILD"
    docker_image_name: "lucassabreu/openshift-k8s-cli"
    docker_image_tag: "latest"
    execute_commands:
    - ENV="${execution.branch.name}"
      GITHUB_TOKEN="${GITHUB_TOKEN}"
      OPENSHIFT_NAMESPACE="${OPENSHIFT_NAMESPACE}"
      OPENSHIFT_API_URL="${OPENSHIFT_API_URL}"
      OPENSHIFT_TOKEN="${OPENSHIFT_TOKEN}"
      ./k8s/destroy
```

Nesse pipeline manual basicamente chamamos o script `k8s/destroy` (que esta abaixo) que simplesmente destrói o ambiente inativa ele no GitHub.

```bash
#!/bin/bash

echo ">> Connecting to OpenShift..."
oc login "$OPENSHIFT_API_URL" --token "$OPENSHIFT_TOKEN"
oc project "$OPENSHIFT_NAMESPACE"

echo ">> Removing old application..."
oc delete all -l "app=$ENV"

k8s/github-deployment "lucassabreu/k8s-pr-envs" "$GITHUB_TOKEN" inactive "$ENV" >> /dev/null
```

Agora podemos chamar ele para eliminar os ambientes de branch em aberto.

Fontes até o momento:

[**lucassabreu/k8s-pr-envs** v4](https://github.com/lucassabreu/k8s-pr-envs/tree/v4)

* * *

Um comportamento que ainda não conseguimos reproduzir usando o Buddy e GitHub é destruir os ambientes quando o Pull Request é finalizado.

Para resolver esse problema podemos adicionar um webhook no GitHub e dispararmos o pipeline através desse webhook. Isso pode ser feito de várias formas, usando Lambda Functions ou um endpoint para esse fim.

No caso criei um novo Pod com um contêiner que criei (`lucassabreu/buddy-works-pullrequest-webhook`) e associei ela no meu projeto no GitHub.

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen-usando-github/webhooks.png" >}}

E pronto tenho um processo completo, mesmo que se esqueçam de derrubar o ambiente no momento que o merge acontecer automaticamente o ambiente
será destruído.

* * *

Abaixo esta o meu "webhook" caso opte por um caminho semelhante e poder
ter uma base de como é a chamada.

[**lucassabreu/buddy-works-pullrequest-webhook**](https://github.com/lucassabreu/buddy-works-pullrequest-webhook)

* * *

Foi mais complexo implementar a integração do OpenShift com o GitHub, mas ainda sim temos um grande ecossistema de integrações que nos permitem contornar essa questão, e o resultado continua sendo o esperado.

