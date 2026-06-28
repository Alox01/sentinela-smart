# Banco de Dados

Este projeto foi preparado para usar PostgreSQL, especialmente via Supabase.

Enquanto `DATABASE_URL` nao estiver configurada, o servidor continua funcionando em memoria com o simulador. Quando a variavel existir e a dependencia `pg` estiver instalada, o servidor passa a salvar snapshots de status, configuracoes e comandos no banco.

## Passos no Supabase

1. Criar um projeto gratuito no Supabase.
2. Abrir o SQL Editor.
3. Executar o conteudo de `database/schema.sql`.
4. Copiar a connection string PostgreSQL do projeto.
5. Configurar no ambiente do servidor:

```bash
DATABASE_URL=postgresql://...
```

6. Instalar a dependencia do driver PostgreSQL no servidor:

```bash
npm install pg
```

7. Iniciar o servidor.

Se tudo estiver certo, o log deve mostrar:

```text
Persistencia PostgreSQL habilitada.
```

## Separacao Entre Simulador e Hardware

O banco nao precisa ser separado para simulador e hardware real.

Use:

- `dispositivos.tipo_dispositivo`: `simulador` ou `hardware`
- `leituras.fonte`: `simulador`, `hardware` ou `manual`

Assim os dados de teste ficam rastreaveis e podem ser filtrados ou removidos depois.
