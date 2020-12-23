import { Component, OnInit, NgZone, ChangeDetectorRef } from '@angular/core';
//import {teste} from './teste';
import { FormsModule } from '@angular/forms';
import { Web3Service } from './../Web3Service';
import { HttpClient } from '@angular/common/http';
import { ConstantesService } from '../ConstantesService';
import { Router, ActivatedRoute } from '@angular/router';

import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { BnAlertsService } from 'bndes-ux4';
import { Alocacao, Subcredito } from './Alocacao';

import { Utils } from '../shared/utils';







@Component({
  selector: 'app-aloca-valores-contas-bndes',
  templateUrl: './aloca-valores-contas-bndes.component.html',
  styleUrls: ['./aloca-valores-contas-bndes.component.css']
})
export class AlocaValoresContasBndesComponent implements OnInit {

  selectedAccount: any;
  alocacao: Alocacao; 
  maskCnpj: any;


  constructor(private http: HttpClient, private constantes: ConstantesService,private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService,
    private web3Service: Web3Service, private router: Router, private zone: NgZone, private ref: ChangeDetectorRef) { 
    
    

    let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 1000});
    
  }
  async ngOnInit() {
    this.maskCnpj = Utils.getMaskCnpj();     
    this.alocacao = new Alocacao();
    this.inicializaAlocacao();
    this.recuperaSaldoBNDESToken();

  }

  inicializaAlocacao() {
    this.alocacao.SaldoAtual = 0;
    this.alocacao.ValorA_Alocar=0;
    this.alocacao.disponivelParaAlocacao=0;
  }



  

  
 

  async recuperaContaSelecionada() {

    let self = this;
    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
  
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
  
      this.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + this.selectedAccount);

      if (!(await this.web3Service.isResponsibleForInitialAllocation())) {
        let s = "essa conta nao é responsavel pela Alocação";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      }

      self.recuperaSaldoBNDESToken();
      
    }
  
  }  
  
  async recuperaSaldoBNDESToken() {
  
    //this.disponivelParaAlocacao = await this.web3Service.getMintedBalance();
    //this.SaldoAtual = await this.web3Service.getDisbursementBalance();
    this.alocacao.disponivelParaAlocacao = await this.web3Service.getMintedBalance();
    this.alocacao.SaldoAtual= await this.web3Service.getDisbursementBalance();
    
  }


  async alocarValor(){
    let self = this;

    if (!(await this.web3Service.isResponsibleForInitialAllocation())) {
      let s = "essa conta nao é responsavel pela Alocação";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }
    if(this.alocacao.SaldoAtual < this.alocacao.ValorA_Alocar){
      let s = "Valor a alocar maior que o valor disponivel";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }
    
    let idConta = await this.web3Service.getIdByAddressSync( await this.web3Service.getCurrentAccountSync());
    //let verificadoDeMudanca1=this.disponivelParaAlocacao;
    //let verificadoDeMudanca2=this.SaldoAtual;

    await this.web3Service.alocaRecursosDesembolso(idConta,<number>(this.alocacao.ValorA_Alocar)).then(
      
      function(txHash) { 
        
        self.alocacao.hashID = txHash;

        Utils.criarAlertasAvisoConfirmacao( txHash, 
                                            self.web3Service, 
                                            self.bnAlertsService, 
                                            "A alocação está sendo enviada para a blockchain.", 
                                            "A alocação foi confirmada na blockchain.", 
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

   /*
    this.SaldoAtual = await this.web3Service.getDisbursementBalance();
    this.disponivelParaAlocacao = await this.web3Service.getMintedBalance();
    while(verificadoDeMudanca1 == this.disponivelParaAlocacao){
      this.disponivelParaAlocacao = await this.web3Service.getMintedBalance();
    }
    while(verificadoDeMudanca2 == this.SaldoAtual){
      this.SaldoAtual = await this.web3Service.getDisbursementBalance();
    }
    */
  }
  
 

}
