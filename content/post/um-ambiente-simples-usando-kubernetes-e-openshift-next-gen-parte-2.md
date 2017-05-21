+++
tags = ["Openshift","Kubernetes","Introduction","Simple","Docker"]
date = "2017-03-08"
title = "Um ambiente simples usando Kubernetes e OpenShift Next Gen - Parte 2"
toc = false
draft = true
images = ["/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/header.png"]

prev = "/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/"
next = "/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-2/"

+++

{{< figure src="/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/header.png" >}}

Este post é parte de uma série sobre o básico necessário para usar o Kubernetes, caso você não tenha lido os post anteriores recomendo lê-los e depois voltar aqui para não ficar perdido.

-   Parte 1 - Conceitos Básicos: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1)
-   Parte 3 - Volumes Persistentes: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-3)
-   Parte 4 - Segredos: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-4)

* * *

Conhecendo os componentes básicos explicados no [post anterior](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1) posso preparar a aplicação que mostrei para o Kubernetes.

O primeiro passo é definir quais são os Pods do meu cluster.

Embora o primeiro impulso seja colocar cada um dos contêineres em um Pod distinto e seguir em frente, esse não é necessariamente a melhor forma de defini-los. Por exemplo, em situação certos contêineres tem o mesmo objetivo, ou dependem muito um do outro é uma boa ideia mantê-los juntos.

Mas para a minha aplicação faz mais sentido um Pod por contêiner, um para o servidor HTTP e outro para o banco de dados.

Como não é uma boa ideia simplesmente definir um Pod diretamente, criei dois Deployments o `node-deployment` e o `db-deployment`.

*No momento da escrita desse post os Deployments ainda estavam marcados como uma versão beta, mas já são bastante usados, então é confiável.*

{{< gist lucassabreu 66bcc63f8eefb4d61b0e149204d5b05b >}}

O primeiro Deployment é para o `db-deployment`. Os arquivos de configuração são simples de ler, sempre começamos o arquivo dizendo o tipo de objeto que será criado, o `metadata` e definimos as `specs` (que variam para cada tipo de componente).

Defini que preciso de apenas um Pod (`replica`) e que as mesmas serão identificáveis pelas labels: `name=db-pod`.

Outras duas informações importantes são `ports` e `volumeMounts`.

-   `ports` define quais portas deverão ser expostas no Pod e permite que possam ser mapeadas nos Services posteriormente. Também é recomendado dar nomes às mesmas (`mysql-port`), assim podemos usar o nome como identificador no lugar de números.
-   `volumeMounts` define todos os volumes do contêiner, dessa forma o volume de dados do MySQL precisou ser mapeado (`/var/lib/mysql`).

{{< gist lucassabreu f7196c220fe9758b31334422172ebcc7 >}}

O segundo Deployment é do servidor HTTP, chamei-o de `node-deployment`. Ele segue as mesmas regras do anterior, sendo até mais simples.

A novidade aqui é o `db-service`, que vou explicar agora:

{{< gist lucassabreu 88d78bb5ee645bea01a93b2b12eb4eef >}}

O `db-service` é o nome do Service que defini para agrupar os Pods de banco de dados, o Service ficou bem simples e basicamente tem duas partes:

-   `selector` define uma regra para selecionar quais Pods fazem parte do Service, no caso estou usando uma regra bem simples de `name=db-pod`.
-   `ports` permite que você mapeie as portas dos Pods para uma porta no Service, no caso estou roteando a porta de nome `mysql-port` para a `3306` do Service. Assim toda chamada para `db-service:3306` será direcionada para a `mysql-port` de um dos Pods.

{{< gist lucassabreu f74cc97d1520471693655e0f34f46452 >}}

O `node-service` segue a mesma lógica, mas para os Pods do servidor HTTP.

{{< gist lucassabreu 157e8b8299fa4583a45d8faf37c8008f >}}

Por fim criei uma Route para expor o serviço `node-service` para a Internet. Eu poderia definir qual o nome de host, mas como não o fiz o OpenShift irá gerar uma URL automaticamente para mim.

Essa URL pode ser descoberta entrando na Dashboard do OpenShift ou com o comando `oc get routes`:

{{< gist lucassabreu a895defcc927e2f7fc86c90bd23b36f2 >}}

Para aplicar as configurações no cluster a OpenShift disponibiliza um cliente de linha de comando, que usa basicamente a mesma estrutura do `kubectl`, o `oc`. Então tudo que precisa ser feito é executar:

{{< gist lucassabreu a0db51d0d36187ee63017ed36ad066ff >}}

* * *

As instruções de como instalar o cliente e configurá-lo estão nesse
link: <https://console.preview.openshift.com/console/command-line>.

* * *

#### \*\*\* Update 2017–04–29 \*\*\*

Se estiver lendo esse artigo algum tempo depois de lançado, a OpenShift fechou o preview e o link anterior não funciona, mas ainda é possível baixar o `oc` client em:

[**openshift/origin** origin - Enterprise Kubernetes for Developers](https://github.com/openshift/origin/releases "https://github.com/openshift/origin/releases")

* * *

Caso não queira criar os todos esses fontes, pode pegá-los aqui: <https://github.com/lucassabreu/openshift-next-gen/tree/v1>; ou executar:

```
git clone -b v1 \
    https://github.com/lucassabreu/openshift-next-gen.git
```

* * *

Agora no console do OpenShift deverão aparecer todos esses componentes
rodando.

{{< figure src="/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-2/openshift-dashboard.png"
        title="eu fiz algumas brincadeiras antes de chegar aqui, então tenho mais versões dos deploys ☺" >}}

Caso esteja acompanhando as etapas, você já deve ter visto esse Dashboard, mas caso esteja apenas lendo: esse Dashboard é a tela principal dos clusters que você criar no OpenShift; basta clicar aqui, autenticar-se com o GitHub, criar um **Project**, e pronto em **Overview** você verá os componentes surgirem e sumirem em tempo real conforme vai aplicando as configurações.

Voltando, nesse momento temos o mesmo comportamento da aplicação local, rodando dentro do Kubernetes, empenhando o mínimo possível de configuração.

Mas existem alguns problemas no que foi definido.

O primeiro é que os `db-pods` estão totalmente efêmeros, ou seja, se eu adicionar novos dados nele, no momento que o Pod fosse destruído os dados iriam junto e sem backup !

Irei mostrar como resolver esse problema no próximo post.

Próximo Post: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-3/)
