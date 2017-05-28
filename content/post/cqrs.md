+++
draft = true
date = "2017-05-28T19:32:14Z"
title = "CQRS - Uma Introdução"
description = "CQRS é um termo que comumente aparece em discussões sobre arquitetura, junto com outros conceitos, como Event Sourcing, Reporting Database, DDD, etc. Vou tentar dismistificar o que é CQRS, e dar um exemplo simples de como ele é aplicado"
images = []
tags = ["CQRS","Basic","Concept"]
toc = false

+++

<!--more-->

* Explicar sobre confusões no conceito
* Delimitar o conceito
* Introduzir alguns exemplos e usos
* Aplicação de exemplo?

Eu ouvia falar  de CQRS com alguma frequência para se definir arquiteturas e modelagens de sistemas, e normalmente vejo vários outros conceitos associados quando falam dele, como Event Sourcing, Reporting Database e DDD. O que me levou a acreditar que CQRS fosse um grande monstro usando essas mecânicas que por si só já carregam uma complexidade.

Como parte das minhas metas na [Coderockr](http://blog.coderockr.com) me propus a entender melhor o que é o CQRS e acabei descobrindo que é bem mais simples do que esperava. 

Nesta postagem pretendo explicar a proposta do CQRS e as vantagens que ele pode trazer a um projeto.

* * *

Então vamos lá, vamos começar com a sigla, CQRS  significa: Command-Query Responsibility Segregation; em tradução livre seria: “Segregação de Responsabilidade entre Consulta e Comandos”, a ideia basicamente seria isso: separar sua aplicação em duas partes, uma para executar comandos, que alteram estado; e outro para recuperar esse estado ou partes dele. Ou seja, ao invés de construirmos um CRUD convencional, que compartilha os mesmos modelos entre todas as chamadas, construímos conjuntos de serviços que executam comandos ou consultas nos nossos dados, mas que utilizam modelos separados (quando isso é uma vantagem).

Por exemplo, quando movimentamos uma conta bancária, não precisamos informar todos os detalhes da mesma quando fazemos uma retirada, nosso cliente apenas precisa dizer qual conta, autenticação e valor, as outras informações que possam existir (limite de crédito, correntista, banco, etc) não precisam ser informadas (provavelmente nem precisamos regatá-los do banco de dados), ter modelos distintos para criar, movimentar, alterar modalidade, alterar detalhe de correntista, etc; se vê conveniente, pois custa menos para realizar as chamadas e alterações uma vez que o volume de dados é menor.

Também fica claro de imaginar como usar modelos distintos pode diminuir custos para as consultas, por exemplo, trazer apenas os valores acumulados da conta para retornar o saldo atual ao invés de trazer todas as movimentações e acumulá-las.

Para usar o CQRS é importante que quando estivermos definindo o domínio da nossa aplicação, definirmos as várias ações que temos para os dados, e então separamos estes em dois conjuntos, aquelas que alteram o estado e aqueles que recuperam o estado da nossa aplicação.

Esses dois conjuntos que alteram (comandos) e recuperam (consulta) podem ser agrupados em dois serviços, que terão modelos distintos de dados, uma consulta de relatório, por exemplo, busca os dados num banco em um formato diferente, daquele que usamos para criar esse mesmo dado.

Para exemplificar vamos pensar em um sistema, bem simples, de fluxo de caixa para várias contas, podemos listar algumas atividades que executamos nele:

- criar conta (<i>alterar estado</i>)
- aumentar saldo (<i>alterar estado</i>)
- diminuir saldo (<i>alterar estado</i>)
- saldo no dia x (<i>recuperar estado</i>)
- saldo atual (<i>recuperar estado</i>)
- ver detalhes da conta (<i>recuperar estado</i>)
- extrato da conta (<i>recuperar estado</i>)

Com essas ações podemos pensar em como os dados circulam no nosso sistema.

- **criar conta**: recebe duas informações: nome da conta e saldo inicial; e retorna numero da conta
- **aumentar saldo**: recebe a conta e o valor a incrementar
- **diminuir saldo**: recebe a conta e o valor a descontar
- **saldo no dia**: recebe o dia do saldo e conta, retorna o dia, conta e saldo no dia
- **saldo atual**: recebe uma conta, retorna a conta e saldo no dia atual
- **ver detalhes da conta**: recebe uma conta, retorna nome, saldo inicial e conta
- **extrato da conta**: recebe conta e período, retorna lista com movimentos da conta (data e valor), saldo inicial e nome.

Embora possamos resolver todas as situações acima usando apenas duas entidades Conta e Movimentos; digamos que nosso sistema tenha um crescimento absurdo, mas que seja muito mais comum que os usuários apenas movimentem (aumentar e diminuir saldo) e consultem saldo atual; que qualquer outra ação da aplicação somadas.

São nessas situações que o CQRS mostra valor, se existissem apenas aquelas duas entidades é provável que seu trafego de dados fique muito maior que o necessário, uma vez que o modelo é muito generalista.

* * *

## Show me the code

Como comentei no início muitos outros conceitos andam junto com o CQRS, mas eles não precisam ser utilizados por padrão, não é necessário usar Event Sourcing, Event Driven, Reporting Database ou mesmo DDD para tirar vantagens do CQRS  -  embora ele case bem com esses conceitos.

Para tentar deixar mais claro como fica uma aplicação utilizando CQRS, vou implementar o fluxo de caixa que comentei antes. No caso a minha aplicação irá utlizar PHP com o [Framework Zend Expressive 2](https://docs.zendframework.com/zend-expressive/) e [Doctrine](http://www.doctrine-project.org/) para lidar com o banco de dados. Ter conhecimento de Doctrine pode facilizar em algumas partes, mas vou tentar explicar as partes chave para facilitar a vida.

Para o exemplo irei utilizar dois serviços, um chamado `command` e outro `query`, os dois tem os componentes que comentei agora a pouco, mas irão cobrir funções distintas no sistema, o repositório virou um tipo de "monorepo" com a estrutura abaixo:

<pre>
cqrs-example
├── command
│   ├── cli
│   ├── config
│   ├── data
│   ├── src
│   │   └── App
│   │       ├── Action
│   │       ├── Container
│   │       ├── Migrations
│   │       └── Model
│   ├── vendor
│   └── ...
└── query
    ├── cli
    ├── config
    ├── data
    ├── src
    │   └── App
    │       ├── Action
    │       ├── Container
    │       ├── Migrations
    │       └── Model
    ├── vendor
    └── ...
</pre>

Caso queria acompanhar pode buscar o fonte aqui: [**lucassabreu/cqrs-example** root](https://github.com/lucassabreu/cqrs-example/tree/root)

Primeiro vamos implementar o `command`, nele vamos ter três operações: `create`, `increase` e `decrease`, apenas para demonstração. Para estas ações vou precisar de duas entidades: `Account` e `Movements`, o fonte delas esta abaixo e é bastante simples.

```php
<?php

namespace App\Model;

use Doctrine\ORM\Mapping as ORM;

/**
 * @ORM\Entity
 * @ORM\Table(name="account")
 */
class Account
{
    /**
     * @ORM\Id
     * @ORM\GeneratedValue(strategy="AUTO");
     * @ORM\Column(name="id", type="integer")
     */
    private $id;
    /**
     * @ORM\Column(name="name", type="string", length=100)
     */
    private $name;
    /**
     * @ORM\Column(name="initial_balance", type="decimal", precision=18, scale=2)
     */
    private $initialBalance;
    /**
     * @ORM\OneToMany(targetEntity="Movement", mappedBy="account")
     */
    private $movements;

    public function __construct(string $name, float $initialBalance = 0)
    {
        $this->name = $name;
        $this->initialBalance = $initialBalance;
        $this->movements = new \Doctrine\Common\Collections\ArrayCollection;
    }

    public function getName() : string
    {
        return $this->name;
    }

    public function getInitialBalance() : float
    {
        return $this->initialBalance;
    }
}
```
<p class="code-legend">command/src/App/Model/Account.php</p>

```php
<?php

namespace App\Model;

use Doctrine\ORM\Mapping as ORM;
use DateTime;

/**
 * @ORM\Entity
 * @ORM\Table(name="movement")
 */
class Movement
{
    const INCREASE = 1;
    const DESCREASE = 0;

    /**
     * @ORM\Id
     * @ORM\GeneratedValue(strategy="AUTO");
     * @ORM\Column(name="id", type="integer")
     */
    private $id;
    /**
     * @ORM\ManyToOne(targetEntity="Account")
     * @ORM\JoinColumn(name="account_id", referencedColumnName="id")
     */
    private $account;
    /**
     * @ORM\Column(name="date", type="datetime")
     */
    private $date;
    /**
     * @ORM\Column(name="type", type="smallint", precision=1)
     */
    private $type;
    /**
     * @ORM\Column(name="value", type="decimal", precision=18, scale=2)
     */
    private $value;

    public function __construct(Account $account, float $value, DateTime $date = null)
    {
        $this->account = $account;
        $this->setValue($value);
        $this->date = $date ?: new DateTime;
    }

    public function setValue(float $value) : self
    {
        if ($value === 0) {
            throw new \InvalidArgumentException('Movements value must not be zero !');
        }
        $this->value = $value;
        $this->type = $value > 0 ? self::INCREASE : self::DECREASE;
        return $this;
    }

    public function getValue() : float
    {
        return $value;
    }

    public function getType() : int
    {
        return $this->type;
    }

    public function getAccount() : Account
    {
        return $this->account;
    }

    public function setDate(DateTime $date) : self
    {
        $this->date = $date;
        return $this;
    }

    public function getDate() : DateTime
    {
        return $this->date;
    }
}
```
<p class="code-legend">command/src/App/Model/Movement.php</p>

Com a ajuda do Doctrine essas duas classes vão criar estas duas tabelas:

{{< figure src="./erd.png" >}}

Para os comandos da nossa aplicação teremos apenas esse modelo, pois é um contexto bem simples. Primeiramente vamos criar o comando `create`, para tanto vou precisar registrar uma nova Action no Zend Expressive, mas não se preocupe, a única parte importante para nós dessa alteração é esta:

```php
```

