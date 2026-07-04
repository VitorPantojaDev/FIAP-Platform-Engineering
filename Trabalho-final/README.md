# 04 - Trabalho Final: a Vortex recria sua infraestrutura com um push

> **Mês 4. Segunda-feira, 8h.**
> Você é Platform Engineer na **Vortex Mobility**, a startup de micromobilidade que saiu de 3 para 30 cidades em um ano. Nos três últimos meses você transformou a infraestrutura: virou código com Terraform (Mês 1), configurou o GitLab Runner com Ansible (Mês 2) e montou o pipeline de CI/CD com gate de segurança (Mês 3).
> **Helena Marques**, Head de Engenharia de Plataforma, te chama para uma conversa antes do conselho:
>
> > *— "Aprendemos cada peça separada. Agora preciso de uma prova de que tudo se conecta. Quero um projeto único, end-to-end, que mostre que a Vortex consegue recriar e validar a infraestrutura do zero com um `git push`. Esse é o material que vou levar ao board para justificar o investimento em plataforma."*
>
> Diego Tavares, seu mentor SRE, passa na sua mesa e completa:
>
> > *— "É o momento de responder, de verdade, a pergunta que perseguiu a gente o ano inteiro: **quanto tempo a Vortex leva para recriar toda a sua infraestrutura do zero, de forma confiável e auditável?** No começo a resposta era 'dias, na mão, e ninguém tinha certeza'. Mostra que hoje é 'um push, automatizado e validado'."*

Este é o **Trabalho Final** da disciplina. Ele consolida tudo que você praticou nos módulos 01 (Terraform), 02 (Ansible) e 03 (CI/CD) em **um único projeto entregável**: um repositório no GitLab que, a cada `push` na branch principal, valida o código Terraform, barra configuração insegura e provisiona a infraestrutura da Vortex de forma reproduzível e auditável.

> [!WARNING]
> **Pré-requisitos obrigatórios antes de começar:**
>
> - [ ] Módulo **01 - Terraform** concluído (você sabe rodar `plan`/`apply`, criar módulos, usar `count`, state remoto no S3 e workspaces)
> - [ ] Módulo **02 - Ansible** concluído (você entende como o GitLab Runner é provisionado — aqui você **não** o sobe na mão, um script faz isso na Parte 0)
> - [ ] Módulo **03 - CI/CD** concluído (você fez ao menos um pipeline rodar `plan`/`apply` com etapa de validação)
> - [ ] Credenciais AWS do Academy atualizadas no Codespaces
> - [ ] Acesso ao seu GitLab com permissão para criar repositório e runner
>
> **Valide rapidamente que o essencial está de pé:**
>
> ```bash
> aws sts get-caller-identity
> terraform -version
> ```
>
> Se o primeiro retornar o JSON com seu `Account`/`Arn` e o segundo mostrar `Terraform v1.10` ou superior, você está pronto.
>
> **Tempo estimado total: 4 a 6 horas** (execução pura ~1h30 + tempo para escrever o `DECISION.md`, depurar o pipeline, observar os jobs no GitLab e validar `dev`/`prod`). Recomendamos dividir em duas sessões.

## Objetivo

Provar — com um artefato funcional e um documento de decisão — que a infraestrutura da Vortex é **código versionado, reproduzível e validado automaticamente**. Você vai partir do código da demo **Count** (módulo 01) e evoluí-lo até um projeto modular, parametrizado por ambiente (`dev`/`prod`), com state remoto no S3 e um pipeline de CI/CD de 3 etapas que roda no seu próprio Runner.

## O que você vai entregar

Ao final, você terá um **repositório GitLab** que:

- transforma a demo Count em um **módulo Terraform reutilizável** que recebe a quantidade de nós atrás do load balancer como parâmetro;
- nomeia os recursos por **workspace/ambiente** (ex: `nginx-prod-002`, `alb-dev`, `vortex-sg-prod`);
- guarda o **estado remoto no S3**, permitindo trabalho em time sem corromper o `terraform.tfstate`;
- separa **dev** e **prod** em workspaces distintos;
- roda um **pipeline de 3 etapas** (validar → revisar/gate de segurança → aplicar) no seu GitLab Runner;
- vem acompanhado de um **`DECISION.md`** (ADR) que justifica as escolhas técnicas para Helena.

> [!TIP]
> Sempre que encontrar um bloco com o título **💡 Clique para entender**, abra-o. Ele traz a anatomia do requisito, o porquê da escolha e links oficiais. Não é obrigatório para concluir, mas aprofunda.

## Mapa do trabalho

| Parte | O que você faz | Requisitos | Tempo |
|-------|----------------|------------|-------|
| [Parte 0](#parte-0---preparação-provisionamento-entregue) | Preparação: projeto GitLab + runner (script pronto) | [P1](#prep-1) · [P2](#prep-2) · [P3](#prep-3) · [P4](#prep-4) | ~20 min |
| [Parte 1](#parte-1---modularizar-a-demo-count) | Modularizar a demo Count | [1](#req-1) · [2](#req-2) | ~60 min |
| [Parte 2](#parte-2---estado-remoto-e-ambientes-devprod) | Estado remoto e ambientes dev/prod | [3](#req-3) · [4](#req-4) · [5](#req-5) · [6](#req-6) | ~60 min |
| [Parte 3](#parte-3---pipeline-de-cicd-end-to-end) | Pipeline de CI/CD end-to-end | [7](#req-7) · [8](#req-8) | ~90 min |
| [Parte 4](#parte-4---documento-de-decisão-adr) | Documento de decisão (ADR) | [9](#req-9) | ~45 min |
| [Parte 5](#parte-5---empacotar-e-submeter) | Empacotar e submeter | [10](#req-10) | ~15 min |

> [!TIP]
> Se travou em algum requisito, clique no número na coluna **Requisitos** acima para ir direto.

## Contexto

Nos módulos anteriores cada conceito foi praticado de forma isolada: um lab para `count`, um lab para state remoto, um lab para o pipeline. No mundo real, esses pedaços precisam coexistir no **mesmo repositório**, governados pelo mesmo fluxo. O Trabalho Final existe para forçar essa integração — é o exercício que mais se parece com o trabalho do dia a dia de um Platform Engineer: pegar peças soltas e transformá-las em um sistema reproduzível.

A base de código é a **demo Count** do módulo 01 ([`01-Terraform/demos/03-Count`](../01-Terraform/demos/03-Count/README.md)): ela já cria N instâncias EC2 com Nginx atrás de um **Application Load Balancer (ALB)**. Seu trabalho é evoluí-la de "demo que roda na sua máquina" para "projeto que roda sozinho via pipeline, em dois ambientes, com histórico auditável".

<details>
<summary><b>💡 Clique para entender: por que essa integração existe</b></summary>
<blockquote>

| Aspecto | Resposta curta |
|---------|----------------|
| **Problema de negócio** | A Vortex aprendeu as ferramentas, mas precisa provar ao board que elas se combinam em um fluxo confiável. |
| **Pergunta que responde bem** | "Conseguimos recriar tudo do zero, sem clicar no console, e com alguém revisando antes?" |
| **Pergunta que responde mal** | "Qual o desenho ótimo de rede multi-conta?" — isso é arquitetura avançada, fora do escopo aqui. |
| **Quando acontece na vida real** | Toda empresa que sai de "infra clicada" para "infra como código" passa por este projeto de consolidação. |

Documentação oficial:
- [Terraform modules](https://developer.hashicorp.com/terraform/language/modules)
- [Terraform backends — S3](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [GitLab CI/CD pipelines](https://docs.gitlab.com/ee/ci/pipelines/)

</blockquote>
</details>

---

## Parte 0 - Preparação (provisionamento entregue)

### Resultado esperado desta parte

Seu **runner próprio** de pé e **online** no GitLab, pronto para rodar o pipeline — sem você configurar servidor na mão. Esta parte **não é o foco do trabalho** (subir o runner você já aprendeu no Módulo 02); por isso ela é a mais automatizada possível: você cria o projeto, gera o token e roda **um script** que provisiona tudo.

> [!NOTE]
> O que **vale nota** no Trabalho Final é o **código** que você escreve a partir da Parte 1 (o módulo Terraform, os workspaces e o `.gitlab-ci.yml`). O provisionamento do runner é só o palco — deixamos pronto de propósito para você gastar seu tempo no que importa.

---

<a id="prep-1"></a>

**Passo 0.1.** No **GitLab**, crie um **projeto novo** para este trabalho (ex: `trabalho-final`). Guarde a URL SSH dele — você vai usá-la na Parte 3 para dar `push` no código.

---

<a id="prep-2"></a>

**Passo 0.2.** Ainda no GitLab, em **Settings → CI/CD → Runners**, clique em **Create project runner**, marque as tags `shell` e `terraform` e **copie o token** (`glrt-...`). É o mesmo fluxo do [Módulo 02](../02-Ansible/01-provisionando-gitlab-runner/README.md#parte-5---gerando-o-token-do-runner-e-guardando-no-ssm) — como o projeto é novo, o token também é novo.

---

<a id="prep-3"></a>

**Passo 0.3.** No **terminal do Codespaces**, guarde o token no **SSM Parameter Store** (o script e o playbook leem dele — nada de segredo em arquivo). Troque `glrt-COLE-SEU-TOKEN-AQUI` pelo token do passo 0.2:

```bash
aws ssm put-parameter \
  --name "/fiap/gitlab-runner/token" \
  --type SecureString \
  --value "glrt-COLE-SEU-TOKEN-AQUI" \
  --region us-east-1 \
  --overwrite
```

---

<a id="prep-4"></a>

**Passo 0.4.** Rode o script de provisionamento. Ele instala o tooling, sobe a EC2 do runner e a configura via Ansible — **tudo em um comando** (leva ~5 min):

```bash
bash /workspaces/FIAP-Platform-Engineering/Trabalho-final/provisionamento/subir-runner.sh
```

Ao terminar, confirme em **Settings → CI/CD → Runners** que o runner aparece **online**.

<details>
<summary><b>💡 Clique para entender: o que o script faz (e por que ele existe)</b></summary>
<blockquote>

O `subir-runner.sh` reaproveita **o mesmo código do Módulo 02** (o Terraform da EC2 + o playbook Ansible). Ele: descobre seu bucket de state, confirma o token no SSM, prepara o Ansible (venv + `boto3` + collections + `session-manager-plugin`), sobe a EC2 (`terraform apply`) e registra o runner (`ansible-playbook`, conectando via SSM — sem SSH).

Por que entregar isso pronto? Porque **subir o runner não é o que este trabalho avalia** — você já fez isso no Módulo 02. O valor do Trabalho Final está no código que vem a seguir. Automatizar o palco tira fricção do que não gera nota.

O runner roda numa EC2 com o `LabRole` (instance profile), então o `terraform` do pipeline já terá acesso à AWS **sem** nenhuma credencial no GitLab.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: <code>token nao encontrado</code> ou <code>bucket base-config-* nao encontrado</code></b></summary>
<blockquote>

- **Token**: refaça o passo 0.3 (o `put-parameter`). Confira com `aws ssm get-parameter --name /fiap/gitlab-runner/token --with-decryption --region us-east-1 --query 'Parameter.Value' --output text`.
- **Bucket**: o script procura um bucket começando com `base-config`. Confirme que o bucket do setup (Módulo 01) existe: `aws s3 ls | grep base-config`.

</blockquote>
</details>

### Checkpoint

- [ ] O projeto do trabalho existe no seu GitLab.
- [ ] O token do runner está no SSM (`/fiap/gitlab-runner/token`).
- [ ] O script terminou e o runner aparece **online** em Settings → CI/CD → Runners.

---

> [!IMPORTANT]
> ## ✋ Daqui em diante começa o trabalho que será avaliado
> A partir da Parte 1, é **você** que desenvolve: o módulo Terraform, os workspaces e o `.gitlab-ci.yml`. O palco (runner) já está pronto — o foco agora é **código e lógica**.

---

## Parte 1 - Modularizar a demo Count

### Resultado esperado desta parte

A lógica da demo Count vira um **módulo reutilizável** que recebe a quantidade de nós como variável, chamado por um arquivo raiz.

---

<a id="req-1"></a>

**Requisito 1.** Transforme os arquivos da demo Count em um **módulo** que recebe a quantidade de nós atrás do load balancer como uma variável de entrada.

> 📚 **Revisar como criar módulo?** Veja a demo **[01.2 - Modules](../01-Terraform/demos/02-Modules/README.md)** (fronteira do módulo, variáveis de entrada, `source`).

- Crie uma pasta de módulo (ex: `modules/web-cluster/`) com os recursos da demo Count (`aws_instance`, `aws_lb`, `aws_lb_target_group`, `aws_lb_listener`, `aws_security_group`, data sources de VPC/subnet).
- Declare uma variável de entrada, por exemplo `variable "node_count"`, e use-a no `count` das instâncias.
- O módulo **não** deve conter um bloco `backend` nem o `provider "aws"` duplicado — isso fica no arquivo raiz que o chama.

<details>
<summary><b>💡 Clique para entender: por que parametrizar a quantidade de nós</b></summary>
<blockquote>

Na demo Count o número de instâncias estava fixo (`count = 2`). Um módulo bom é **agnóstico ao ambiente**: a mesma lógica serve para 1 nó em `dev` e 4 em `prod`. Promover o número a variável (`node_count`) transforma o módulo em um contrato — quem chama decide o tamanho, o módulo decide como construir.

Padrão mental: o módulo é uma "função"; as variáveis são seus parâmetros; os `outputs` são seu retorno.

Documentação oficial:
- [Input Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Module composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)

</blockquote>
</details>

---

<a id="req-2"></a>

**Requisito 2.** Crie o **arquivo raiz** que chama o módulo recém-criado, passando o `node_count` e expondo o DNS do load balancer (ALB) como `output`.

```hcl
# main.tf (raiz)
module "web_cluster" {
  source     = "./modules/web-cluster"
  node_count = var.node_count
}

output "alb_dns" {
  value = module.web_cluster.alb_dns_name
}
```

> [!IMPORTANT]
> Valide a sintaxe localmente antes de seguir, sem precisar de credenciais:
>
> ```bash
> cd /workspaces/FIAP-Platform-Engineering/Trabalho-final
> terraform init -backend=false
> terraform fmt -check
> terraform validate
> ```

### Checkpoint

- [ ] Existe uma pasta de módulo com os recursos da demo Count.
- [ ] O módulo expõe `node_count` como variável de entrada.
- [ ] O arquivo raiz chama o módulo e `terraform validate` passa.

---

## Parte 2 - Estado remoto e ambientes dev/prod

### Resultado esperado desta parte

O state vive no S3 e existem dois ambientes (`dev` e `prod`) com recursos nomeados pelo workspace.

---

<a id="req-3"></a>

**Requisito 3.** Adicione **estado remoto no S3** no arquivo raiz que chama os módulos.

> 📚 **Revisar state remoto?** Veja a demo **[01.4 - State](../01-Terraform/demos/04-State/README.md)** (backend S3, `terraform init` migrando o state, lock).

```hcl
# backend.tf (raiz)
terraform {
  backend "s3" {
    bucket = "base-config-<SEU-RM>"
    key    = "trabalho-final/terraform.tfstate"
    region = "us-east-1"
  }
}
```

> [!CAUTION]
> Nomes de bucket S3 **não podem ter espaços** e são globais. Use o padrão `base-config-<SEU-RM>` (substitua `<SEU-RM>` pelo seu RM). **Não** versione `terraform.tfstate` no Git — adicione-o ao `.gitignore`.

<details>
<summary><b>⚠ Se der erro: <code>Error: Failed to get existing workspaces: S3 bucket does not exist</code></b></summary>
<blockquote>

O bucket precisa existir **antes** do `terraform init`. Crie-o uma vez:

```bash
aws s3 mb s3://base-config-<SEU-RM> --region us-east-1
```

Depois rode `terraform init` novamente — ele migra o state para o S3.

</blockquote>
</details>

---

<a id="req-4"></a>

**Requisito 4.** Faça com que os **nomes das máquinas** definidas dentro do módulo sigam o **workspace** atual. Exemplo: `nginx-prod-002`, `nginx-dev-001`.

> 📚 **Revisar workspaces e `terraform.workspace`?** Veja a demo **[01.5 - Workspaces](../01-Terraform/demos/05-Workspaces/README.md)** (nomear recursos pelo workspace, states isolados).

```hcl
tags = {
  Name = "nginx-${terraform.workspace}-${format("%03d", count.index + 1)}"
}
```

---

<a id="req-5"></a>

**Requisito 5.** Faça com que os nomes do **ALB** (`aws_lb`), do **Target Group** (`aws_lb_target_group`) e do **Security Group** do módulo também contenham o workspace (ex: `alb-prod`, `tg-prod`, `vortex-sg-prod`).

> [!NOTE]
> O nome de um `aws_lb` (ALB) e de um `aws_lb_target_group` aceita no máximo 32 caracteres e só letras, números e hífens. Mantenha curto: `alb-${terraform.workspace}` e `tg-${terraform.workspace}` são suficientes.

> [!CAUTION]
> O **nome do Security Group não pode começar com `sg-`** — a AWS reserva esse prefixo para os IDs (`sg-01ab...`) e recusa com `invalid value for name (cannot begin with sg-)`. Use um prefixo próprio, ex: `vortex-sg-${terraform.workspace}` (vira `vortex-sg-prod`). Descrições de Security Group também devem ser ASCII, sem acentos.

---

<a id="req-6"></a>

**Requisito 6.** Crie um ambiente de **dev** e um de **prod** usando workspaces, com alguma diferença real entre eles (ex: `dev` com 1 nó, `prod` com 3).

> 📚 A demo **[01.5 - Workspaces](../01-Terraform/demos/05-Workspaces/README.md)** mostra `terraform workspace new/select/list` e como um mesmo código gera ambientes isolados.

```bash
cd /workspaces/FIAP-Platform-Engineering/Trabalho-final
terraform workspace new dev
terraform workspace new prod
terraform workspace list
```

> [!TIP]
> Use a flag `-auto-approve` para evitar o "type 'yes' to confirm" em todos os `apply`/`destroy` deste trabalho — não ensina nada novo e tira fricção. Diferencie o `node_count` por ambiente via arquivos `dev.tfvars` / `prod.tfvars` ou condicional sobre `terraform.workspace`.

### Checkpoint

- [ ] `backend.tf` aponta para `s3://base-config-<SEU-RM>` e `terraform init` migrou o state.
- [ ] EC2, ALB, Target Group e Security Group carregam o workspace no nome.
- [ ] `terraform.tfstate` está no `.gitignore`.
- [ ] `terraform workspace list` mostra `dev` e `prod`, e os dois se diferenciam.

---

## Parte 3 - Pipeline de CI/CD end-to-end

### Resultado esperado desta parte

Um repositório no GitLab roda um pipeline de 3 etapas no seu Runner próprio, deixando as EC2s no ar e um relatório de validação disponível.

---

<a id="req-7"></a>

**Requisito 7.** Suba **somente** o código deste trabalho (módulo + raiz + `.gitlab-ci.yml`) para o **projeto que você criou na Parte 0** (passo 0.1). O pipeline vai rodar no **runner que você provisionou na Parte 0** — que já está online e autentica na AWS pelo **`LabRole` (instance profile da EC2)**. Ou seja, **você não configura credencial AWS nenhuma no GitLab**, igual ao [Módulo 03](../03-CICD/01-Primeiro-pipeline/README.md).

> [!IMPORTANT]
> Confirme que o runner da Parte 0 está **online** em Settings → CI/CD → Runners. Como ele roda numa EC2 com o `LabRole`, o `terraform` no pipeline já tem acesso à AWS — sem `AWS_ACCESS_KEY_ID`/`SECRET` no repositório. Isso também evita o problema das credenciais do Academy, que são temporárias e expiram.

> [!CAUTION]
> **Nunca** faça commit do `terraform.tfstate` nem de segredos. Confira o `.gitignore` antes do primeiro push.

---

<a id="req-8"></a>

**Requisito 8.** Adicione um **pipeline de 3 etapas** (`stages`) que roda no seu **GitLab Runner próprio** (Módulo 02). É o **mesmo padrão** que você montou no módulo de CI/CD — reaproveite o que aprendeu no [Lab 03.1](../03-CICD/01-Primeiro-pipeline/README.md) (estrutura `plan`/`apply` + artefato) e no [Lab 03.2](../03-CICD/02-Validando-e-gerando-relatorios/README.md) (gate de validação):

1. **validar** — `terraform fmt -check`, `terraform init`, `terraform validate`;
2. **revisar/gate** — roda o **gate de segurança do Lab 03.2** (o **Checkov**, e opcionalmente `tflint`/`terraform test`) sobre o código, **barrando** configuração insegura **antes** do apply e anexando o relatório como artefato;
3. **aplicar** — `terraform apply -auto-approve` no workspace escolhido, deixando as EC2s no ar.

```yaml
# .gitlab-ci.yml (esqueleto — adapte ao seu projeto)
stages:
  - validar
  - revisar
  - aplicar

validar:
  stage: validar
  script:
    - terraform fmt -check
    - terraform init
    - terraform validate

revisar:
  stage: revisar
  script:
    - terraform plan -out=plan.tfplan
  artifacts:
    paths:
      - plan.tfplan

aplicar:
  stage: aplicar
  script:
    - terraform apply -auto-approve plan.tfplan
```

<details>
<summary><b>💡 Clique para entender: por que o gate vem ANTES do apply</b></summary>
<blockquote>

A demanda do Diego no Mês 3 foi clara: *"um gate de segurança que barre configuração insegura ANTES de chegar na nuvem"*. A ordem das etapas importa — validar e revisar são baratos e rápidos; aplicar é caro e cria recursos reais. Falhar cedo (no `validate`/gate) evita provisionar uma infra insegura e depois ter que destruí-la. É o princípio de "falhe cedo, falhe pequeno".

Documentação oficial:
- [GitLab CI/CD stages](https://docs.gitlab.com/ee/ci/yaml/#stages)
- [Terraform in CI/CD](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: pipeline fica em <code>pending</code> e nunca roda</b></summary>
<blockquote>

O job está esperando um Runner. Verifique em **Settings → CI/CD → Runners** se o Runner do Módulo 02 está **online** e habilitado para este projeto. Se ele tiver tags, o job precisa ter as mesmas tags (ou desmarque "Run untagged jobs").

</blockquote>
</details>

### Checkpoint

- [ ] O repositório no GitLab tem só o código deste trabalho (sem state, sem credenciais).
- [ ] O pipeline tem 3 etapas e elas rodam no seu Runner próprio.
- [ ] As EC2s da demo Count estão acessíveis pelo DNS do ELB.
- [ ] O relatório de validação/plan está disponível como artefato no pipeline.

---

## Parte 4 - Documento de decisão (ADR)

### Resultado esperado desta parte

Um `DECISION.md` que justifica, em linguagem de negócio, as escolhas técnicas para Helena.

---

<a id="req-9"></a>

**Requisito 9.** Copie o arquivo [`DECISION_TEMPLATE.md`](./DECISION_TEMPLATE.md) para `DECISION.md` na raiz do seu projeto e preencha-o. Ele deve registrar: o contexto da demanda da Helena, a decisão de design do módulo, a estratégia de state, o desenho do pipeline, as alternativas descartadas e as consequências.

> [!NOTE]
> Em entrevistas técnicas seniores, **escrever sobre a decisão** é tão valorizado quanto escrever o código. Um ADR mostra maturidade: você documenta não só o que fez, mas o porquê e o que descartou.

### Checkpoint

- [ ] `DECISION.md` existe e está preenchido (sem campos `_____` em branco).
- [ ] Há ao menos uma alternativa descartada com justificativa.

---

## Parte 5 - Empacotar e submeter

### Resultado esperado desta parte

Um pacote `.zip` submetido no portal da FIAP, mais o link do repositório GitLab.

---

<a id="req-10"></a>

**Requisito 10.** Faça um **zip** dos arquivos deste exercício (código Terraform + `.gitlab-ci.yml` + `DECISION.md`, **sem** o diretório `.terraform/` nem o `terraform.tfstate`) e submeta no **portal da FIAP**.

```bash
cd /workspaces/FIAP-Platform-Engineering/Trabalho-final
zip -r trabalho-final-<SEU-RM>.zip . -x '*.terraform/*' -x '*.tfstate*' -x '*.git/*'
```

**Itens da submissão:**

- [ ] `trabalho-final-<SEU-RM>.zip` (código + `.gitlab-ci.yml` + `DECISION.md`)
- [ ] **Link do repositório GitLab** (cole no campo de texto da entrega no portal)
- [ ] **Print do pipeline verde** com as 3 etapas concluídas
- [ ] **Print do relatório/artefato** de validação anexado ao pipeline

> [!IMPORTANT]
> **Prazo e forma de entrega**: `<prazo definido pelo professor>`. Confira o portal da FIAP / comunicado da turma para a data exata e o canal de submissão.

> [!CAUTION]
> **Destrua a infraestrutura ao terminar** — este é o fim do arco, então derrube **tudo**: a infra do trabalho (EC2 + ALB em `dev` e `prod`) **e** o runner da Parte 0. Deixar ligado consome o orçamento do Learner Lab.
>
> ```bash
> # 1) infra do trabalho, nos dois ambientes
> cd /workspaces/FIAP-Platform-Engineering/Trabalho-final
> terraform workspace select dev  && terraform destroy -auto-approve
> terraform workspace select prod && terraform destroy -auto-approve
>
> # 2) o runner da Parte 0 (a EC2 provisionada pelo script)
> cd /workspaces/FIAP-Platform-Engineering/02-Ansible/01-provisionando-gitlab-runner/terraform-gitlab-runner
> terraform destroy -auto-approve
> ```

### Checkpoint

- [ ] O `.zip` foi gerado sem `.terraform/` nem `.tfstate`.
- [ ] A submissão no portal inclui o link do GitLab e os prints.
- [ ] A infraestrutura do trabalho foi destruída nos dois ambientes **e** o runner da Parte 0 também.

---

## Conclusão

Se você chegou até aqui, então construiu — em um único projeto — a resposta à pergunta que perseguiu a Vortex o ano inteiro:

- modularizou a demo Count em um módulo parametrizável;
- moveu o state para o S3, viabilizando trabalho em time;
- separou `dev` e `prod` com recursos nomeados por workspace;
- montou um pipeline de 3 etapas que valida, barra o inseguro e aplica — tudo no seu Runner;
- documentou a decisão em um ADR.

**Mensagem para Helena**: *"A infraestrutura da Vortex hoje é código versionado. Um `push` na branch principal valida, revisa e provisiona tudo do zero — de forma confiável e auditável. A resposta para o board é: não são mais dias na mão, é um push."*

---

## Recursos de apoio

- [Como criar módulos reutilizáveis (Gruntwork)](https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d)
- [Composição de módulos (Terraform)](https://developer.hashicorp.com/terraform/language/modules/develop/composition)
- [Módulos (Terraform)](https://developer.hashicorp.com/terraform/language/modules)
- [Data sources AWS (instances)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instances)

---

<details>
<summary><b>💡 Glossário rápido — termos que aparecem neste trabalho</b></summary>
<blockquote>

| Termo | O que é |
|-------|---------|
| **Módulo (Terraform)** | Conjunto de arquivos `.tf` em uma pasta que pode ser chamado por outros, com variáveis de entrada e outputs. É a unidade de reuso da IaC. |
| **State remoto** | O `terraform.tfstate` guardado fora da máquina (aqui no S3), para que vários engenheiros e o pipeline compartilhem o mesmo estado sem corromper. |
| **Workspace** | Mecanismo do Terraform para manter múltiplos states isolados a partir do mesmo código (ex: `dev` e `prod`). |
| **ALB (Application Load Balancer)** | Load balancer de camada 7 da AWS (`aws_lb` + `aws_lb_target_group` + `aws_lb_listener`), usado na demo Count para distribuir tráfego entre as EC2s com Nginx. |
| **Security Group** | Firewall virtual da AWS que controla o tráfego de entrada/saída de uma instância. |
| **Pipeline (CI/CD)** | Sequência de etapas automatizadas (stages/jobs) executadas pelo GitLab a cada push. |
| **GitLab Runner** | Agente que executa os jobs do pipeline. Aqui é o Runner próprio provisionado no Módulo 02 com Ansible. |
| **Gate de segurança** | Etapa que barra configuração insegura antes do apply, falhando o pipeline se algo não passar na verificação. |
| **ADR** | Architecture Decision Record — documento curto que registra uma escolha técnica: contexto, decisão, alternativas, consequências. |
| **Artefato (CI/CD)** | Arquivo produzido por um job (ex: `plan.tfplan`, relatório) e disponibilizado para download no pipeline. |

</blockquote>
</details>

<details>
<summary><b>💡 Como pedir ajuda se travou</b></summary>
<blockquote>

Antes de abrir issue/perguntar, colete estas 4 informações — elas reduzem o tempo de resposta em 10×:

1. **Em que requisito você está** (ex: "Requisito 8, etapa `revisar` do pipeline")
2. **Mensagem de erro literal** (copia-cola completo do log do job no GitLab, não screenshot — texto é pesquisável)
3. **Saída de** `terraform workspace list` **e** `terraform validate` (mostra o estado real do projeto)
4. **O que você já tentou**

Canais (em ordem de prioridade):

- **Issues do repositório**: [github.com/vamperst/FIAP-Platform-Engineering/issues](https://github.com/vamperst/FIAP-Platform-Engineering/issues)
- **E-mail do professor**: `Rafael@rfbarbosa.com`
- **LinkedIn**: [rafael-barbosa-serverless](https://www.linkedin.com/in/rafael-barbosa-serverless/)
- **Antes de tudo**: confira se o Runner está online (~70% dos "pipeline pendente" são Runner offline ou tag incompatível) e se o bucket do backend existe.

</blockquote>
</details>
