// No dashboard_screen.dart:

// 1. Adicionar import no topo, junto dos outros:
import 'movimentacoes_screen.dart';

// 2. No onSelected do PopupMenuButton, adicionar:
if (valor == 'movimentacoes') {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const MovimentacoesScreen())).then((_) => onRefresh());
}

// 3. No itemBuilder, adicionar um PopupMenuItem novo (sugiro logo depois do
//    "Conectar Telegram", antes do "Apagar todas as apostas"):
const PopupMenuItem(value: 'movimentacoes', child: Text('Saques e depósitos')),
