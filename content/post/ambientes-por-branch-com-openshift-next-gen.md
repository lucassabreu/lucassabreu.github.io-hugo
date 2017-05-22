+++
draft = true
images = ["/post/ambientes-por-branch-com-openshift-next-gen/header.png"]
tags = ["Openshift","Gitlab","Continuous Integration","Pull Request","Github"]
date = "2017-05-01"
title = "Ambientes por Branch com OpenShift Next Gen"
description = "Como melhorar o processo de Pull Request usando deploys por branch usando OpenShift Next Gen e Continuous Integration"
toc = false

+++

<!--more-->

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen/header.png" >}}

Hoje na [Coderockr](https://blog.coderockr.com) utilizamos [Pull Requests e Code Reviews](https://blog.coderockr.com/a-import%C3%A2ncia-da-revis%C3%A3o-de-c%C3%B3digo-a1a8b41ed7ff) como uma ferramenta de qualidade nos nossos desenvolvimentos, e tem garantido resultados nesse sentido.

Mas mesmo com esse processo eventualmente temos de lidar com alguns problemas como, por exemplo, funções que interferem umas nas outras depois de aprovadas, permitir que os Testers possam avaliar as melhorias, e garantir que todos as mudanças feitas na branch principal podem ser enviadas para produção.

Esses problemas podem ser reduzidos, ou até eliminados; se, mesmo antes de aprovar os PRs; os Testers conseguissem trabalhar sobre essas melhorias e só repassadas para a branch principal após a aprovação deles.

Desse modo o fonte principal não só passou pelo Review de outros desenvolvedores, como foi testado pela equipe de QA, dando ainda mais confiança no mesmo.

Mas subir ambientes de homologação para cada um dos PRs, automaticamente ou sobre demanda, não é um problema trivial, envolve subir máquinas, garantir que esta rodando a versão atualizada, liberar portas, etc.

Uma forma que encontramos para resolver esse problema é utilizando um cluster Kubernetes (ou a versão da Red Hat o OpenShift), pois essas ações são bem simples de realizar com ele e ainda mais fáceis se forem automatizadas.

Agora vou explicar como montar um exemplo simples, um para o GitLab e outro para o GitHub, integrando com o OpenShift da [Getup Cloud](https://getupcloud.com.br).

Sobre uma introdução ao Kubernetes/OpenShift pode ver aqui:

[**Um ambiente simples usando Kubernetes e OpenShift Next Gen - Parte 1**](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/)

O cliente de linha de comando pode ser baixado em:

[**openshift/origin** origin - Enterprise Kubernetes for Developers](https://github.com/openshift/origin/releases)

#### GitLab: Integrations, CI, Registry e Environments

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen/gitlab.png" >}}

A primeira experiencia que fizemos foi com o [GitLab](https://gitlab.com), principalmente pela integração que ele traz com o Kubernetes, e as outras ferramentas que ele oferece que acabaram cobrindo todo o escopo do problema.

O que queremos montar é um ambiente por branch/PR que deve ser facilmente criado e destruído. Para demonstrar criei um repositório no GitLab com uma aplicação bem simples que apenas retorna uma página estática, mas é o suficiente para o objetivo.

{{< figure src="/post/ambientes-por-branch-com-openshift-next-gen/helloworld-view.png"
    title="retorno do serviço helloworld" >}}

Primeiramente criei a base da aplicação usando Docker, a mesma gera uma página com o conteúdo acima. O que vale destacar nesse primeiro momento é que já configurei um processo de CI simples:

```yaml
build:
  image: docker:latest
  services:
    - docker:dind
  stage: build
  script:
    - docker login -u "gitlab-ci-token" -p "$CI_JOB_TOKEN" $CI_REGISTRY
    - docker build --pull -t "$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME" .
    - docker push "$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME"
    - echo "Pushing image $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME"
  only:
    - branches
```
<p class="code-legend">.gitlab-ci.yml</p>

Nesse CI eu construo o contêiner da aplicação para cada commit feito e guardo no registro do próprio GitLab por branch, dessa forma tenho uma versão do meu contêiner para cada uma das branchs que forem criadas e vou atualizando essas versões automaticamente a cada alteração.

Fonte completo até aqui:

[**Files · v1 · Lucas dos Santos Abreu / k8s-pr-envs**](https://gitlab.com/lucassabreu/k8s-pr-envs/tree/v1)

* * *

Nesse momento não tenho nenhum deploy, seja de ambiente de teste, produção ou por branch.

Então vamos adicionar um processo de deploy no OpenShift para o ambiente de produção e testes, sendo que o ambiente de testes é atualizado automaticamente para os commits na master e o de produção apenas quando um usuário disparar o deploy.

Para fazer isso primeiramente temos de configurar a integração entre o OpenShift e o GitLab, para isso vamos em *Settings* &gt; *Integrations* e procuramos *Kubernetes* nas opções. O GitLab irá solicitar algumas informações sobre o ambiente, qual o **Namespace**, o **URL da API** do **Kubernetes** e uma forma de autenticação, que pode ser um **Service Token** ou um **CA Bundle**.

Dessa forma vou criar um novo **Namespace**, como fazer isso vai depender do seu vendor de Kubernetes, no caso da [Getup Cloud](https://getupcloud.com.br), basta ir em <https://portal.getupcloud.com/projects> e criar um novo projeto, o nome do projeto será o **Namespace.**

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen/dashboard-getup.png" >}}

Uma vez com o **Namespace** podemos criar um novo **Service Token** para ser usado no CI do GitLab, no caso para criar um Service Token é necessário criar uma ServiceAccount e dar permissões a mesma, e então pegar o Service Token dela. O script abaixo realiza essas operações:

<pre>
<b>$ oc login https://api.getupcloud.com:443</b>
Authentication required for https://api.getupcloud.com:443 ...
Username: lucas.s.abreu@gmail.com
Password:
Login successful.
...

<b>$ oc project gitlab-k8s-pr-envs #usar o seu projeto</b>
Now using project "gitlab-k8s-pr-envs" on server ...

<b>$ oc create serviceaccount gitlab</b>
serviceaccount "gitlab" created

<b>$ oc policy add-role-to-user admin \</b>
    system:serviceaccount:gitlab-k8s-pr-envs:gitlab

<b>$ oc describe serviceaccount gitlab</b>
Name:  gitlab
Namespace: gitlab-k8s-pr-envs
Labels:  <none>

Image pull secrets: gitlab-dockercfg-qj9o9

Mountable secrets:  gitlab-token-6ael2
                    gitlab-dockercfg-qj9o9

Tokens:             gitlab-token-6ael2
                    gitlab-token-zkk6u

<b>$ oc describe secret gitlab-token-6ael2</b>
Name:  gitlab-token-6ael2
Namespace: gitlab-k8s-pr-envs
Labels:  <none>
Annotations: kubernetes.io/service-account.name=gitlab
  kubernetes.io/service-account.uid=zzz

Type: kubernetes.io/service-account-token

Data
====
ca.crt:  1066 bytes
namespace: 18 bytes
service-ca.crt: 2182 bytes
token:  <i><b>token-do-openshift-que-estou-ocultando</i></b>
</pre>

Agora que temos o token gerado basta adicionar essas informações no
GitLab.

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen/gitlab-k8s-integration.png" >}}

Você pode confirmar se passou os dados corretos com o botão de teste no GitLab.

Certo, agora o GitLab consegue conversar com o OpenShift. Podemos então alterar nossas regras de CI para criar duas novas etapas: *staging* e *production*, que irão realizar o deploy dos nossos ambientes padrões, sendo que *staging* será disparada automaticamente por commits na master e *production* ficará como manual.

O .`gitlab-ci.yml` ficou como abaixo (já usando a integração com OpenShift):

```yaml
stages:
  - build
  - staging
  - production

variables:
  KUBE_DOMAIN: getup.io

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u "gitlab-ci-token" -p "$CI_JOB_TOKEN" $CI_REGISTRY
    - docker build --pull -t "$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME" .
    - docker push "$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME"
    - echo "Pushing image $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME"
  only:
    - branches

staging:
  stage: staging
  image: lucassabreu/openshift-k8s-cli:latest
  variables:
    CI_ENVIRONMENT_URL: http://$CI_PROJECT_NAME-staging.$KUBE_DOMAIN
  environment:
    name: staging
    url: http://$CI_PROJECT_NAME-staging.$KUBE_DOMAIN
  script:
    - k8s/deploy
  only:
    - master

production:
  stage: production
  image: lucassabreu/openshift-k8s-cli:latest
  variables:
    CI_ENVIRONMENT_URL: http://$CI_PROJECT_NAME.$KUBE_DOMAIN
  environment:
    name: production
    url: http://$CI_PROJECT_NAME.$KUBE_DOMAIN
  when: manual
  script:
    - k8s/deploy
  only:
    - master
```
<p class="code-legend">.gitlab-ci.yml (v2)</p>

As mudança são os novos stages `staging` e `production`; as variáveis novas `KUBE_DOMAIN` e `CI_ENVIRONMENT_URL`; e o script `k8s/deploy`. Vamos por partes.

A variável `KUBE_DOMAIN` vai ajudar a deixar o nosso processo de deploy mais simples, basicamente nós colocamos nela o domínio base que o OpenShift usa para expor as rotas dele, no caso da Getup seria “*getup.io*”. A `CI_ENVIRONMENT_URL` é completar a `KUBE_DOMAIN` e serve para informar o `k8s/deploy` qual endereço ele deve expor o ambiente, ele deve sempre terminar com o `KUBE_DOMAIN` e deve ser igual a `url` da chave `environment`, pois é por essa chave que o GitLab sabe onde os ambientes estão expostos.

As etapas de `staging` e `production` irão fazer o deploy dos nossos ambientes e como comentei antes o ambiente de *staging* terá deploy automático para todo commit na master, enquanto *production* irá esperar uma ação do usuário. No mais as duas etapas são iguais mudando apenas a URL que estão sendo expostas. Estou usando a imagem `lucassabreu/openshift-k8s-cli` que é basicamente um `ubuntu` com o `oc` instalado.

O script `k8s/deploy` está abaixo e ele basicamente se autentica contra a API do OpenShift usando o *Service Token* que criamos antes, destrói a aplicação antiga e executa o deploy de uma nova.

```bash
#!/bin/bash

oc login "$KUBE_URL" --token "$KUBE_TOKEN"
oc project "$KUBE_NAMESPACE"

HOSTNAME="$CI_ENVIRONMENT_URL"

# remove protocol from URL
HOSTNAME="${HOSTNAME/\http:\/\//}"
HOSTNAME="${HOSTNAME/\http:\/\//}"

IMAGE_TAG="$CI_REGISTRY_IMAGE:$CI_BUILD_REF_NAME"
ENV="$CI_ENVIRONMENT_SLUG"

echo ">> Deleting old application..."
oc delete all -l "app=$CI_ENVIRONMENT_SLUG"

echo ">> Deploying image $IMAGE_TAG to env $ENV at $HOSTNAME..."

sed "
  s|__HOSTNAME__|$HOSTNAME|;
  s|__ENV__|$ENV|;
  s|__IMAGE_TAG__|$IMAGE_TAG|;
  " k8s/full.yml | oc apply -f -
if [ $? != 0 ]; then
  exit 1
fi

echo ">> Deployed to $CI_ENVIRONMENT_URL"
```
<p class="code-legend">k8s/deploy</p>

Vale ressaltar que é importante marcar os componentes do ambiente com `app=$CI_ENVIRONMENT_SLUG`, pois é assim que o GitLab consegue encontrar eles e lhe retornar status sobre eles.

Também estou usando um truque de “*templating*” com o YAML que define os ambientes para poder inserir as variáveis de cada ambiente nele. Existem outras ferramentas mais avançadas como o [Helm](https://github.com/kubernetes/helm), mas para o meu exemplo templating com `sed` é o suficiente.

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

Agora, depois que do commit das alterações, o GitLab faz o *build*, o deploy da *staging* e *production* (manual); podemos ver na área *Environments* do GitLab que os ambientes estão rodando, ele inclusive traz alguns comandos para facilitar a vida: link para a URL do ambiente, terminal dentro do Pod e opção de Re-deploy.

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen/gilab-envs.png" >}}

Fonte completo até agora:

[**Files · v2 · Lucas dos Santos Abreu / k8s-pr-envs**](https://gitlab.com/lucassabreu/k8s-pr-envs/tree/v2)

* * *

Agora que temos o *build* da nossa aplicação e um deploy automatizado, vamos adicionar a função de deploy por branch.

Basicamente precisamos de duas novas etapas no nosso CI, uma para subir o ambiente para uma branch e outro para destruir esse ambiente para evitar consumir recursos sem necessidade.

Para isso fiz as seguintes alterações nos `.gitlab-ci.yml`:

```yaml
stages:
  - build
  - review
  - staging
  - production
  - cleanup

review:
  stage: review
  image: lucassabreu/openshift-k8s-cli:latest
  variables:
    CI_ENVIRONMENT_URL: http://$CI_PROJECT_NAME-$CI_ENVIRONMENT_SLUG.$KUBE_DOMAIN
  environment:
    name: r/$CI_COMMIT_REF_NAME
    url: http://$CI_PROJECT_NAME-$CI_ENVIRONMENT_SLUG.$KUBE_DOMAIN
    on_stop: stop_review
  script:
    - k8s/deploy
  only:
    - branches
  except:
    - master

stop_review:
  stage: cleanup
  image: lucassabreu/openshift-k8s-cli:latest
  environment:
    name: r/$CI_COMMIT_REF_NAME
    action: stop
  when: manual
  variables:
    GIT_STRATEGY: none
  script:
    - oc login "$KUBE_URL" --token "$KUBE_TOKEN"
    - oc project "$KUBE_NAMESPACE"
    - oc delete deployments -l "app=$CI_ENVIRONMENT_SLUG"
    - oc delete all -l "app=$CI_ENVIRONMENT_SLUG"
  only:
    - branches
  except:
    - master

[...]
```
<p class="code-legend">.gitlab-ci.yml (v3)</p>

Basicamente adicionei as duas novas etapas, `review` basicamente faz a mesma coisa que `staging`, mas usa um nome de ambiente dinâmico baseado na branch; e tem um `enviroment:on_stop` que basicamente indica o que fazer quando a branch for removida.

Na etapa `stop_review` executo alguns comandos para eliminar o ambiente quando for chamada, é importante deixar essa como `manual` para que ela não apague sozinha o ambiente quando terminar as outras etapas.

Os comandos da etapa `stop_review` precisam estar definidos diretamente no `.gitlab-ci.yml`, pois quando essa etapa for executada é possível que a branch e commits dela não existam mais, é também por esse motivo que informamos a variável `GIT_STRATEGY` como `NO` evitando que sequer seja checado se a branch/commit de origem existem.

Agora quando crio uma nova branch automaticamente é criado um novo ambiente para a mesma no OpenShift.

Para testar criei a branch `a-change` e fiz a seguinte alteração:

```diff
   <img id="logo" src="logo.svg"
     alt="CodeRocker" title="CodeRocker" />
   <h1>Hello World !</h1>
+  <h2>(with a change)</h2>
 </body>
 </html>
```
<p class="code-legend">public/index.html (pr)</p>

Assim que dei o `git push` começou o deploy do novo ambiente `r/a-change`, logo que terminou pude verificar na área de ambientes do GitLab que estava rodando, e tem as mesmas operações disponíveis que os outros, mais a opção de parada (`stop_review`):

{{< figure class="big" src="/post/ambientes-por-branch-com-openshift-next-gen/branch-env.png" >}}

Já rodando as alterações:

{{< figure src="/post/ambientes-por-branch-com-openshift-next-gen/a-change.png" >}}

Fontes com essas alterações em:

[**Files · v3 · Lucas dos Santos Abreu / k8s-pr-envs**](https://gitlab.com/lucassabreu/k8s-pr-envs/tree/v3)

* * *

Após essas alterações podemos implementar a regra de merge apenas após testes pela equipe de QA, sem interferência de outras atividades que foram aplicadas no meio do caminho e permitindo um controle melhor sobre o que esta pronto para ir para a produção.

* * *

A postagem acabou ficando bem grande apenas para falar do processo no GitLab, por isso vou criar um segundo post sobre como fazer isso no GitHub, abaixo esta o link para ele:

[**Ambientes por Branch com OpenShift Next Gen usando GitHub**](/post/ambientes-por-branch-com-openshift-next-gen-usando-github)
