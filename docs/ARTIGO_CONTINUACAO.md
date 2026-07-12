# Continuação do artigo — seções para colar no Word

Texto pronto para as seções que faltavam no `.docx` (Resultados, Conclusão,
Resumo/Abstract). Escrito a partir dos fatos dos `docs/` e do código — sem
dados inventados. Ajustar formatação (numeração, negrito, espaçamento) ao
padrão do template ao colar.

---

## ANÁLISE DE DISCUSSÕES E RESULTADOS

Como resultado deste trabalho, a camada de software da plataforma foi
implementada e validada em três componentes integrados: o aplicativo móvel
desenvolvido em Flutter, a API de persistência e sincronização construída em
Node.js com o framework Express, e o ambiente simulado do controlador da
estufa. O ambiente de nuvem, indicado na metodologia como elemento a ser
definido, foi materializado por meio da hospedagem da API na plataforma Render
e do armazenamento do histórico em um banco de dados PostgreSQL gerenciado
(Supabase). No aplicativo, foi utilizado o banco de dados local Isar,
responsável por guardar o cadastro das estufas, o histórico de leituras, os
eventos de cada ciclo de secagem e a fila de comandos pendentes de
sincronização.

O simulador em JavaScript, descrito na metodologia, foi evoluído para se
comportar como um controlador virtual: além de gerar as leituras de
temperatura e umidade, ele passou a enviá-las ativamente para a API em nuvem
por requisições HTTP, reproduzindo o mesmo contrato de comunicação previsto
para o dispositivo físico. Essa decisão permitiu validar o fluxo completo de
dados — do controlador à nuvem e da nuvem ao aplicativo — antes da integração
com o hardware real, que poderá substituir o simulador sem alterações no
aplicativo, uma vez que o contrato da API é o mesmo.

### Operação híbrida e alternância de conexão

A lógica de comunicação híbrida proposta foi implementada e verificada em
funcionamento. O aplicativo resolve a conexão de forma automática e
transparente ao usuário, priorizando a rede local: primeiro tenta o endereço
do controlador na rede Wi-Fi e, apenas quando este não responde, recorre à API
em nuvem. Um indicador na interface exibe o modo ativo — local, nuvem ou
offline. Nos testes, ao interromper o controlador na rede local, o aplicativo
passou a consumir os dados da nuvem em poucos segundos; ao restabelecer o
controlador, a leitura voltou a ser feita pela rede local, confirmando o
comportamento previsto pelo paradigma de Computação de Borda discutido no
referencial teórico. Os tempos-limite de resposta foram calibrados de forma
distinta para cada destino, uma vez que a nuvem, acessada pela internet,
responde naturalmente mais devagar que o controlador na rede local.

### Sincronização e resiliência a quedas de conexão

A estratégia de sincronização por carimbos de tempo com resolução de conflitos
do tipo última escrita vence (Last Write Wins), fundamentada na seção 2.5, foi
implementada por campo de configuração: temperatura, umidade e silenciamento
do alarme carregam, cada um, o seu próprio timestamp. Nos testes de validação,
ajustes realizados no aplicativo sem conectividade não foram perdidos: os
comandos entram em uma fila local e, quando a comunicação é restabelecida, são
enviados ao controlador, que aplica apenas as alterações mais recentes que as
suas — comandos antigos são identificados pelo carimbo de tempo e descartados,
evitando que uma configuração ultrapassada sobrescreva outra mais atual.

A mesma resiliência foi aplicada ao caminho das leituras. Quando o controlador
perde o acesso à internet, as leituras que seriam enviadas à nuvem são
preservadas em um buffer local e reenviadas em ordem cronológica assim que a
conexão retorna. Nos testes, quedas de internet simuladas não resultaram em
perda de dados: as leituras represadas apareceram no banco em nuvem após a
reconexão, preenchendo o período da queda. Com isso, o histórico do processo
de secagem permanece íntegro mesmo em cenários de conectividade intermitente,
que constituem o problema central deste trabalho.

### Histórico operacional e relatórios por ciclo de secagem

Para o armazenamento do histórico, adotou-se uma política de persistência
seletiva: durante um ciclo de secagem ativo, uma leitura periódica é gravada a
cada dez minutos, e eventos relevantes — acionamento e normalização de alarme,
oscilações significativas em relação ao ajuste, perda e retorno de conexão,
queda e retorno de energia e mudanças de configuração — são gravados
imediatamente. Essa regra evita o crescimento desnecessário do banco sem
comprometer a capacidade de explicar o que ocorreu em cada estufada. No
aplicativo, cada ciclo gera um relatório com resumo do período, linha do tempo
de eventos e gráfico das leituras sobreposto à linha de ajuste, com exportação
em PDF e CSV para arquivamento ou compartilhamento. O histórico gravado pela
nuvem complementa o registro local, preenchendo períodos em que o aplicativo
esteve fechado.

### Alertas de segurança

A lógica de segurança executada pelo controlador foi implementada e ajustada
com base em testes de uso. O alarme de processo dispara quando a temperatura
se afasta mais de 5 °F do ajuste — tolerância definida após validação prática,
por representar melhor o limiar de atenção real do produtor. A umidade,
embora monitorada e registrada, não aciona a sirene por decisão de projeto,
uma vez que o acompanhamento do produtor se concentra na temperatura. Para o
risco de incêndio, discutido na seção 2.2, o sistema adota um limite de
segurança de 175 °F, e a ativação do sensor de chama aciona o alerta crítico
de forma imediata. O silenciamento do alarme pelo aplicativo tem efeito
temporário, garantindo que uma condição persistente volte a alertar o usuário.
Vale registrar que as temperaturas do sistema são expressas em graus
Fahrenheit, escala consolidada no manejo da cura do tabaco e que oferece
granularidade mais fina de ajuste ao produtor.

### Validação e testes

A validação da plataforma combinou três frentes. Primeiro, cenários guiados de
demonstração, cobrindo o funcionamento local sem internet, a alternância
automática entre rede local e nuvem, o envio de comandos em modo offline com
posterior sincronização e a preservação das leituras em buffer durante quedas
de conexão. Segundo, testes automatizados — 62 no servidor e 11 no aplicativo
— cobrindo a lógica de alarme, a máquina de estados de detecção de oscilações
e o rastreamento de quedas de conexão, o que permitiu evoluir o código com
segurança contra regressões. Terceiro, a instalação do aplicativo compilado em
dispositivo Android físico, cuja utilização prática orientou refinamentos de
interface e de comportamento, como a calibração dos indicadores visuais e o
ajuste da densidade de pontos dos gráficos.

Em síntese, os resultados indicam que a arquitetura híbrida proposta atende ao
problema formulado na introdução: o monitoramento não é interrompido pela
ausência de internet, os dados e comandos não se perdem durante as quedas e a
nuvem cumpre o papel de histórico e acesso remoto sem se tornar uma
dependência. Como limitações do estágio atual, destacam-se a validação
realizada sobre o controlador simulado — a integração com o dispositivo físico
permanece como etapa complementar — e o envio de alertas com o aplicativo
fechado, que depende de infraestrutura de notificações push planejada, mas
ainda não implementada.

---

## CONCLUSÃO

Com este artigo conclui-se que a construção de uma camada de software híbrida,
orientada pela Computação de Borda e por mecanismos de sincronização baseados
em carimbos de tempo, é um caminho viável para o monitoramento e o controle de
estufas de secagem de fumo em regiões com conectividade instável. O aplicativo
desenvolvido mantém o acompanhamento da estufa pela rede local quando a
internet falha, recorre à nuvem quando o acesso local não está disponível e
preserva comandos e leituras durante as quedas, sincronizando-os de forma
consistente na reconexão. Para o produtor, isso significa acompanhar e ajustar
o processo de cura — etapa crítica para a qualidade e para a segurança da
produção — sem que a instabilidade da rede comprometa o funcionamento do
sistema ou a integridade do histórico operacional.

Alguns aspectos foram identificados, podendo gerar estudos para eventuais
melhorias futuras. O primeiro é a integração com o controlador físico da
estufa, desenvolvida em projeto complementar, para a qual o contrato de
comunicação já se encontra definido e validado sobre o ambiente simulado. O
segundo é o envio de notificações push, permitindo que alertas de alarme,
incêndio e falta de energia alcancem o produtor mesmo com o aplicativo
fechado; a arquitetura para esse recurso foi projetada, prevendo um mecanismo
de vigilância na nuvem capaz de detectar o silêncio prolongado do controlador.
Relacionado a isso, identificou-se que a distinção remota entre falta de
energia e falta de internet não pode ser resolvida apenas por software: exige
que o controlador disponha de alimentação de reserva e sensor de tensão da
rede elétrica, de modo a comunicar a queda de energia antes de se desligar —
requisito já documentado para a etapa de hardware. Por fim, apontam-se como
evoluções a política de retenção de dados no banco em nuvem e o agendamento de
ações diretamente no controlador, garantindo que rotinas críticas não dependam
do aplicativo estar em execução.

---

## RESUMO (substituir o placeholder)

A adoção de tecnologias de Internet das Coisas no meio rural ainda é limitada
pela instabilidade da conexão à internet, o que compromete sistemas que
dependem exclusivamente de processamento em nuvem. No contexto das estufas de
secagem de fumo, em que o controle contínuo de temperatura e umidade é
determinante para a qualidade da produção e para a prevenção de incêndios,
essa limitação torna-se crítica. Este trabalho tem como objetivo desenvolver a
camada de software de uma plataforma IoT híbrida para o monitoramento e o
controle dessas estufas, capaz de operar mesmo em cenários de conectividade
instável. Para isso, foram desenvolvidos um aplicativo móvel multiplataforma
em Flutter, uma API de persistência e sincronização em Node.js hospedada em
nuvem com banco de dados PostgreSQL, e um simulador do controlador da estufa
utilizado na validação. A comunicação prioriza a rede local, com a nuvem como
suporte complementar, e a sincronização utiliza carimbos de tempo com
resolução de conflitos por última escrita vence, aplicada por campo de
configuração. Os resultados demonstraram a alternância automática entre rede
local e nuvem, a preservação de comandos e leituras durante quedas de conexão
com sincronização consistente na reconexão, e a geração de histórico e
relatórios por ciclo de secagem. Conclui-se que a arquitetura híbrida proposta
mantém o monitoramento funcional independentemente da disponibilidade de
internet, restando como etapas futuras a integração com o controlador físico e
o envio de notificações push.

**PALAVRAS-CHAVE:** Internet das Coisas; Computação de Borda; sincronização de
dados; estufas de secagem de fumo.

---

## ABSTRACT (tradução do resumo)

The adoption of Internet of Things technologies in rural areas is still
limited by unstable internet connectivity, which compromises systems that rely
exclusively on cloud processing. In the context of tobacco curing barns, where
continuous temperature and humidity control is decisive for production quality
and fire prevention, this limitation becomes critical. This work aims to
develop the software layer of a hybrid IoT platform for monitoring and
controlling these barns, capable of operating even under unstable connectivity
scenarios. To this end, a cross-platform mobile application was developed in
Flutter, along with a persistence and synchronization API in Node.js hosted in
the cloud with a PostgreSQL database, and a barn controller simulator used for
validation. Communication prioritizes the local network, with the cloud as
complementary support, and synchronization relies on timestamps with
last-write-wins conflict resolution, applied per configuration field. The
results demonstrated automatic switching between local network and cloud,
preservation of commands and readings during connectivity drops with
consistent synchronization upon reconnection, and the generation of history
and reports per curing cycle. It is concluded that the proposed hybrid
architecture keeps monitoring functional regardless of internet availability,
with the integration of the physical controller and push notification
delivery remaining as future steps.

**KEYWORDS:** Internet of Things; Edge Computing; data synchronization;
tobacco curing barns.
