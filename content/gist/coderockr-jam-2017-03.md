+++
draft = false
tags = ["Coderockr Jam","Kubernetes","Basics"]
date = "2017-03-11"
title = "Notas Kubernetes - Coderockr Jam 2017-03-11"
description = "Algumas notas e detalhes que anotei sobre o Kubernetes para o Coderockr Jam"
toc = false

+++

<!--more-->

{{< figure class="big" src="https://upload.wikimedia.org/wikipedia/en/0/00/Kubernetes_%28container_engine%29.png" >}}

Kubernetes ou K8s é uma plataforma open source para gestão de cluster de contêineres, desenvolvido pelo Google e doado a _Cloud Native Computing Foundation_, que é uma organização que existe abaixo do _Linux Foundation_.

Tem por objetivo a automoção de um conjunto de funções de cluster: deploy, escalagem e executar aplicações de contêineres em vários hosts. Sendo que normalmente funciona usando _Docker_.

Alguns conceitos importantes para entender a ferramenta:

Pods
----

São o menor componente do K8s, definindo um nó do cluster, ou seja, uma máquina virtual dedicada apenas as funções definidas nela, com o acréscimo de alguns componentes para verificar estado e vida das aplicações sendo executadas dentro delas.

Um `Pod` irá executar um conjunto de contêineres definidos nele e que devem ter a mesma finalidade ou estão ligados de uma forma tão forte que se um falhar os contêineres relacionados devem ser destruídos também.

Também tem a caracteristica de serem tratados como efêmeros, de modo que destruí-los e recriá-los deve ser uma tarefa simples e sem remorços.

Persistent Volume Claim (PVC)
-----------------------------

São volumes de dados persistentes, como os `Pods` tem a caracterica de serem criados e destruídos a qualquer momento existe o risco de perder seus dados, os `Persistent Volume Claims` tem por objetivo cobrir esse problema provendo storages que sobrevivem sem os `Pods`, assim quando o `Pod` for criado poderá se conectar ao mesmo `PVC` e continuar.

Existem vários tipos de drivers de armazenamento para os `PVCs` utilizarem, mas que normalmente dependem do serviço provendo o K8s, por exemplo, o OpenShift apenas provê o EBS do AWS, mas no Google Cloud podem ser usados storages do Google, AWS, locais, etc.

Cron Jobs
---------

Um problema para contêineres é a execução de CRONs, que é por muitos considerado uma má prática gerenciar internamente ao contêiner, que o certo seria o host do contêiner instanciá-lo temporariamente para executar o comando. Assim a responsabidade de schedule da CRON ficaria para o host.

`CRON Jobs` representam a solução do K8s para isso, podem ser criadas schedules de execução de `Pods` do tipo `Job` que irão ser iniciados, executam uma tarefa e morrem.

Caso ocorram falhas ou insucesso na execução um novo `Job` será criado para tentar concluir a tarefa, se assim for configurado.

Labels e Selectors
------------------

Labels é a forma pela qual os componentes (principalmente `Pods`) são marcados e agrupados, através destas marcações e nada mais Services e Controllers identificam seus `Pods`, de forma que uma estruturação ruim de labels/selectors pode levar a Services tentando acessar `Pods` inválidos e Controllers competirem por definições de `Pods`.

Controllers
-----------

`Constrollers` são regras de replicação e deploy que existem para os `Pods` dentro do K8s, eles tem por objetivo realizar a tarefa de deployment, escalagem, verificar vida dos contêineres e eventualmente destruí-los quando param de responder.

Existem alguns tipos de `Controllers`, mas de forma geral eles trabalham mantendo conjuntos de contêineres com determidas definições ativos e criar novos de acordo com regras. Os `Controllers` irão criar ou adotar conjuntos `Pods` que teram uma mesma marcação de `labels`/`selectors` e possuem um "template" de `Pods` dentro deles para saberem como criá-los quando necessário.

Os tipos possíveis são:

 * **ReplicationController**: é o mais simples dos `Controllers`, realizando apenas deploy, escalonamento de Pods e verificando disponibilidade dos mesmos, quando existem `Pods` orfãs que se encaixam em seus selectors eles os acolhem e consideram válidos, mesmo que estes não respeitem seu modelo de `Pods`. São o tipo mais simples de `Controllers` é sugerido dar preferencia aos `Deployments` no lugar deles.
 * **Deployment**: é um `Controller` semelhante ao `ReplicationController`, porém não irá adotar `Pods` que não respeitem a definição de seu template, de modo que caso encontre `Pods` orfãs que não coincidam com a sua definição irá destruí-los e criar novos que estejam conforme o contrato. Quando a definição de um `Deployment` é alterada ele irá verificar se os `Pods` ainda respeitam essa nova definição, caso não respeitem ele irá destruí-los e criar novos `Pods` conforme seu contrato. Também mantém um histórico das suas definições, de modo que o usuário pode facilmente retornar a um estado anterior (`rollout`).
 * **ReplicaSet**: é muito semelhante ao `ReplicationController`, porém permite usar regras de `selector` mais completas e pode utilizar a função "`rolling-update`" que irá verificar a definição dos `Pods` no `selector` e atualizá-los um a um de forma semelhante ao `Deployment`. Em verdade o `Deployment` usa `ReplicaSets` para atualizar o Pods, sendo os itens do seu histórico os `ReplicaSets` já utilizados.
 * **StatefulSet**: representa `Controllers` que devem gerar `Pods` com caracteristicas persistentes, ou que a ordem de criação tenha influência. Quando eles são criados é possível definir um template de `Persistent Volume Claims` que serão criados para cada um dos nós, de modo que quando os mesmos voltam a ativa podem retormar seus estados no momento que sairam do ar. (acho que pode ser útil para construir `Pods` para nós de bancos de dados que funcionam por replicação).
 * **DaemonSet**: é um `Controller` que garante que um certo tipo de `Pod` será adicionado a todos os nós do cluster. Os `Pods` que são criados por ele normalmente são do tipo de coleta de logs (`fluentd`, `logstash`), monitores (`New Relic`, `Prometheus Exporter`) e serviços semelhantes.
 * **Job**: é um `Controller` para executar `Pods` de vida curta, no sentido de pequenos comandos ou execuções que não precisam ser servidas. Normalmente são criados por `Cron Jobs` do K8s.

Services
--------

Como os `Pods` além de efêmeros, podem existir em números variados por culpa dos `Controllers`, não há forma confiável de tentar conectar dois `Pods` diretamente, seja porque o `Pod` que você está dependendo pode morrer e quando voltar terá outro IP, e provavelmente outro nome, ou porque o `Pod` que você "fixou" pode não ser o mas indicado (menos ocupado ou mais próximo).

Para resolver esse problema existem os `Services`, em vez de tentar fazer as chamadas diretamente para um `Pod`, podemos chamar pelo nome de um `Service` e este irá rotear para um `Pod` que esteja abaixo dele.

Os `Services` também são a forma padrão para se expor serviços do cluster para o mundo exterior.

Arquitetura
-----------

{{< figure class="big" src="https://upload.wikimedia.org/wikipedia/commons/b/be/Kubernetes.png" title="arquitetura do kubernetes" >}}

