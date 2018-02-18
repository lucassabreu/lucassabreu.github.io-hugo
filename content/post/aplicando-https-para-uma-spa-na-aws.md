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
Recentemente alteramos a landing page e o SPA do Planrockr para suportar HTTPS, por muito tempo mantemos apenas o backend executando sobre HTTPS, mas percebemos que seria melhor prover nosso frontend sobre HTTPS também, seja para melhorar o [ranking em sites de pesquisa](https://webmasters.googleblog.com/2014/08/https-as-ranking-signal.html), garantir a segurança nas comunicações ou simplesmente passar mais segurança para os nossos usuários. 
