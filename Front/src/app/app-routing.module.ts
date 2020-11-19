import { NgModule }             from '@angular/core';
import { RouterModule, Routes } from '@angular/router';

import { HomeComponent } from './home/home.component';

import { LiberacaoComponent } from './liberacao/liberacao.component';
import { LiquidacaoResgateComponent } from './liquidacao-resgate/liquidacao-resgate.component';
import { AssociaPapelInvestidorComponent } from './associa-papel-investidor/associa-papel-investidor.component';
import { RealizarPagamentoComponent } from './realizar-pagamento/realizar-pagamento.component';

import { ConfirmaDoacaoComponent } from './confirma-doacao/confirma-doacao.component';
import { ResgateComponent } from './resgate/resgate.component';

import { AlocaValoresContasBndesComponent } from './aloca-valores-contas-bndes/aloca-valores-contas-bndes.component';

import { RegistraDoacaoComponent } from './registra-doacao/registra-doacao.component';

/* Sociedade */
import { DashboardDoacaoComponent } from './dashboard-doacao/dashboard-doacao.component';
import { DashboardTransferenciasComponent } from './dashboard-transferencias/dashboard-transferencias.component';
import {DashboardManualComponent } from './dashboard-manual/dashboard-manual.component';
import {DashboardPapeisComponent } from './dashboard-papeis/dashboard-papeis.component';





const routes: Routes = [
  { path: 'bndes', component: HomeComponent },
  { path: 'cliente', component: HomeComponent },
  { path: 'doador', component: HomeComponent },
  { path: 'sociedade', component: HomeComponent },
  { path: 'bndes/confirma-doacao', component:ConfirmaDoacaoComponent },
  { path: 'bndes/liberacao', component: LiberacaoComponent },
  { path: 'bndes/alocar-investimentos', component: AlocaValoresContasBndesComponent},
  { path: 'bndes/associa-papel-investidor', component: AssociaPapelInvestidorComponent},
  { path: 'bndes/liquidar/:solicitacaoResgateId', component: LiquidacaoResgateComponent},
  { path: 'investidor/registra-doacao', component: RegistraDoacaoComponent},  
  { path: 'fornecedor/resgate', component: ResgateComponent },
  { path: 'cliente/realizar-pagamento', component: RealizarPagamentoComponent},
  { path: 'sociedade/dash-papeis', component: DashboardPapeisComponent },
  { path: 'sociedade/dash-doacao', component: DashboardDoacaoComponent },
  { path: 'sociedade/dash-transf', component: DashboardTransferenciasComponent },
  { path: 'sociedade/dash-manuais', component: DashboardManualComponent },
  { path: '', redirectTo: '/sociedade', pathMatch: 'full' },
];


@NgModule({
  imports: [ RouterModule.forRoot(routes) ],
  exports: [ RouterModule ]
})
export class AppRoutingModule {}
