import { Component, OnInit, NgZone } from '@angular/core';
import { ChangeDetectorRef } from '@angular/core';
import { Router } from '@angular/router';

import { Liberacao, Subcredito } from './Liberacao';

import { Web3Service } from './../Web3Service';
import { PessoaJuridicaService } from '../pessoa-juridica.service';


import { BnAlertsService } from 'bndes-ux4';
import { ChangeDetectionStrategy } from '@angular/compiler/src/core';

import { Utils } from '../shared/utils';

@Component({
  selector: 'app-liberacao',
  templateUrl: './liberacao.component.html',
  styleUrls: ['./liberacao.component.css']
})
export class LiberacaoComponent implements OnInit {

  liberacao: Liberacao;

  ultimoCNPJ: string;

  maskCnpj: any;

  selectedAccount: any;


  constructor(private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService, private web3Service: Web3Service,
    private ref: ChangeDetectorRef, private zone: NgZone, private router: Router) {

      let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 1000});

  }

  ngOnInit() {
    this.maskCnpj = Utils.getMaskCnpj();     
    this.liberacao = new Liberacao();
    this.ultimoCNPJ = "";
    this.inicializaLiberacao();
    this.recuperaSaldoBNDESToken();
  }

  inicializaLiberacao() {
    this.liberacao.subcreditos = new Array<Subcredito>();    
    this.liberacao.razaoSocial = null;
    this.liberacao.valor = null;
    this.liberacao.saldoCNPJ = null;
    this.liberacao.numeroSubcreditoSelecionado = null;
  }

 async recuperaContaSelecionada() {

  let self = this;

  

  let newSelectedAccount = await this.web3Service.getCurrentAccountSync();

  if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {

    this.selectedAccount = newSelectedAccount;
    console.log("selectedAccount=" + this.selectedAccount);
    if(!(await this.web3Service.isResponsibleForDisbursement())){
      let s = "conta nao é responsavel por desembolso";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
    }
    self.recuperaSaldoBNDESToken();
    
  }

}  

 async recuperaSaldoBNDESToken() {

  this.liberacao.saldoBNDESToken = await this.web3Service.getDisbursementBalance();
  console.log("Saldo eh " + this.liberacao.saldoBNDESToken);
}


  recuperaInformacoesDerivadasCNPJ() {
    this.liberacao.cnpj = Utils.removeSpecialCharacters(this.liberacao.cnpjWithMask);

    if (this.liberacao.cnpj != this.ultimoCNPJ) {
      this.inicializaLiberacao();
      this.ultimoCNPJ = this.liberacao.cnpj;

      if ( this.liberacao.cnpj.length == 14 ) { 
        console.log (" Buscando o CNPJ do cliente (14 digitos fornecidos)...  ");
        this.recuperaClientePorCNPJ(this.liberacao.cnpj);
      } 
      else {
        this.inicializaLiberacao();
      }  
    }
  }

  async recuperaClientePorCNPJ(cnpj) {
    console.log(cnpj);

    let self = this;

    let rbbID = <number> (await this.web3Service.getRBBIDByCNPJSync(parseInt(cnpj)));

    if (!rbbID) {
      let s = "CNPJ não está cadastrado.";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    } 
    this.liberacao.rbbId = rbbID; 

    this.pessoaJuridicaService.recuperaClientePorCnpj(cnpj).subscribe(
      empresa => {
        if (empresa && empresa.dadosCadastrais) {
          console.log("empresa encontrada abaixo ");
          console.log(empresa);

          this.liberacao.cnpj = cnpj;
          this.liberacao.razaoSocial = empresa.dadosCadastrais.razaoSocial;

          if (empresa["subcreditos"] && empresa["subcreditos"].length>0) {

            for (var i = 0; i < empresa["subcreditos"].length; i++) {
            
              let subStr = JSON.parse(JSON.stringify(empresa["subcreditos"][i]));

              self.includeIfNotExists(self.liberacao.subcreditos, subStr);

              //TODO: otimizar para fazer isso apenas uma vez
              if (i==0) {
                self.liberacao.numeroSubcreditoSelecionado = self.liberacao.subcreditos[0].numero;
                self.atualizaInfoPorMudancaSubcredito();
              }
            }
               
          }
          else {
            let s = "A liberação só pode ocorrer para uma empresa cliente.";
            this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
            console.log(s);
          }
        }
        else {
          let texto = "Nenhuma empresa encontrada com o cnpj " + cnpj;
          console.log(texto);
          Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);

          this.inicializaLiberacao();
        }
      },
      error => {
        let texto = "Erro ao buscar dados da empresa";
        console.log(texto);
        Utils.criarAlertaErro( this.bnAlertsService, texto,error);
        this.inicializaLiberacao();
      });

  }

  async atualizaInfoPorMudancaSubcredito() {

    this.liberacao.saldoCNPJ = 
      await this.web3Service.getBalanceOf(this.liberacao.rbbId, this.liberacao.numeroSubcreditoSelecionado);

  }

  includeIfNotExists(subcreditos, sub) {

    let include = true;
    for(var i=0; i < subcreditos.length; i++) { 
      if (subcreditos[i].numero==sub.numero) {
        include=false;
      }
    }  
    if (include) subcreditos.push(sub);
  }


  async liberar() {

    let self = this;
    if(!(await this.web3Service.isResponsibleForDisbursement())){
        let s = "conta nao é responsavel por desembolso";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
    }

/*    
    let bRD = await this.web3Service.isResponsibleForDisbursementSync();    
    if (!bRD) 
    {
      let s = "Conta selecionada no Metamask não pode executar Liberação.";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
    }
*/


    //Multipliquei por 1 para a comparacao ser do valor (e nao da string)
    if ((this.liberacao.valor * 1) > (this.liberacao.saldoBNDESToken * 1)) {
/*    
        let s = "Não é possível liberar um valor maior do que o saldo de BNDESToken.";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
*/
    }


        console.log(this.liberacao.valor);          


        this.web3Service.liberacao(this.liberacao.rbbId, this.liberacao.numeroSubcreditoSelecionado+"", this.liberacao.valor).then(
      
          function(txHash) { 
            
            self.liberacao.hashID = txHash;

            Utils.criarAlertasAvisoConfirmacao( txHash, 
                                                self.web3Service, 
                                                self.bnAlertsService, 
                                                "A liberação está sendo enviada para a blockchain.", 
                                                "A liberação foi confirmada na blockchain.", 
                                                self.zone) 
            self.router.navigate(['sociedade/dash-transf']);                                                          
      
          },
          function(error) {  
            Utils.criarAlertaErro( self.bnAlertsService, 
              "Erro ao liberar na blockchain. Uma possibilidade é a conta selecionada não ser a do BNDES", 
              error )  
      });    


      Utils.criarAlertaAcaoUsuario( self.bnAlertsService, 
                                    "Confirme a operação no metamask e aguarde a confirmação da liberação." )

    }    
  
}
