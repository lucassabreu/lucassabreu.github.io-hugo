---
title: "Aplicando HTTPS para uma SPA na\_AWS"
date: 2018-02-18T14:44:28.803Z
images: []
draft: true
toc: false
description: Como aplicamos HTTPS para o nosso frontend usando as ferramentas da AWS
tags:
  - aws
  - https
  - cloudfront
  - s3
---
<!-- more -->
Recentemente alteramos a landing page e o SPA do Planrockr para suportar HTTPS, por muito tempo mantemos apenas o backend executando sobre HTTPS, mas percebemos que seria melhor prover nosso frontend sobre HTTPS também, seja para melhorar o [ranking em sites de pesquisa](https://webmasters.googleblog.com/2014/08/https-as-ranking-signal.html), para garantir a segurança nas comunicações ou simplesmente passar mais segurança para os nossos usuários. 

Foi uma tarefa que acabou dando alguma dor de cabeça, não por ser uma tarefa difícil, como estamos usando o S3 da AWS para prover a Landing e o frontend do Planrockr, é apenas uma questão de colocar um CloudFront na frente e alterar a rota no Route 53 e tudo passa a funcionar.

O problema foi que a maioria dos tutoriais que existem na internet sobre habilitar HTTPS no AWS para um SPA passam uma instrução errada que acaba desencadeando um conjunto problemas de comunicação com o S3 que cominou no S3 rejeitar o CloudFront e simplesmente redirecionar para a URL pública do bucket, que acabou quebrando algumas funcionalidades do Planrockr, principalmente no on-boarding.

Para evitar que outros acabem passando por problemas semelhantes e para servir de registro para projetos futuros, abaixo vou descrever a forma correta (e fácil) de habilitar HTTPS usando o S3 e CloudFront da AWS.

---

Para usar HTTPS em um bucket do S3, primeiro é necessário possuir um bucket (😜) 

