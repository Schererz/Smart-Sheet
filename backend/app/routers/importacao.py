from datetime import date
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session

from .. import crud, models, schemas
from ..database import get_db
from ..deps import obter_usuario_atual
from .. import importacao_utils as utils

router = APIRouter(prefix="/importacao", tags=["importacao"])


@router.post("/planilha")
async def importar_planilha(
    arquivo: UploadFile = File(...),
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    nome = (arquivo.filename or "").lower()
    conteudo = await arquivo.read()

    if nome.endswith(".xlsx"):
        linhas = utils.ler_linhas_xlsx(conteudo)
    elif nome.endswith(".csv"):
        linhas = utils.ler_linhas_csv(conteudo)
    else:
        raise HTTPException(status_code=400, detail="Envie um arquivo .xlsx ou .csv")

    if len(linhas) < 2:
        raise HTTPException(status_code=400, detail="A planilha parece vazia (só achei o cabeçalho, ou nem isso)")

    cabecalho, *linhas_dados = linhas
    mapa = utils.mapear_colunas(cabecalho)

    campos_faltando = {"odd", "valor", "casa"} - mapa.keys()
    if campos_faltando:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Não consegui reconhecer as colunas: {', '.join(sorted(campos_faltando))}. "
                "Confira se os nomes das colunas batem com o esperado (ex: Odd, Valor, Casa)."
            ),
        )

    importadas = 0
    erros = []

    for i, linha in enumerate(linhas_dados, start=2):  # start=2: linha 1 é o cabeçalho
        def pega(campo):
            indice = mapa.get(campo)
            return linha[indice] if indice is not None and indice < len(linha) else None

        odd = utils.converter_numero(pega("odd"))
        valor = utils.converter_numero(pega("valor"))
        casa = str(pega("casa")).strip() if pega("casa") else None

        if odd is None or valor is None or not casa:
            erros.append({"linha": i, "motivo": "faltando odd, valor ou casa"})
            continue

        try:
            aposta = schemas.BetCreate(
                data=utils.converter_data(pega("data")) or date.today(),
                casa_de_apostas=casa,
                descricao=str(pega("descricao")).strip() if pega("descricao") else None,
                odd=odd,
                valor_apostado=valor,
                retorno_potencial=utils.converter_numero(pega("retorno")),
                resultado=utils.normalizar_resultado(pega("resultado")),
                origem=schemas.OrigemRegistro.manual,
            )
            crud.criar_aposta(db, usuario.id, aposta)
            importadas += 1
        except Exception as e:
            erros.append({"linha": i, "motivo": str(e)})

    return {
        "total_linhas": len(linhas_dados),
        "importadas": importadas,
        "erros": erros,
    }
