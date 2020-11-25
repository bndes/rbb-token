
import { Component, OnInit, NgZone, ChangeDetectorRef } from '@angular/core';
//import {teste} from './teste';
import { FormsModule } from '@angular/forms';
import { Web3Service } from './../Web3Service';
import { HttpClient } from '@angular/common/http';
import { ConstantesService } from '../ConstantesService';
import { Router, ActivatedRoute } from '@angular/router';

import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { BnAlertsService } from 'bndes-ux4';


@Component({
  selector: 'app-alocar-valor-administrativo',
  templateUrl: './alocar-valor-administrativo.component.html',
  styleUrls: ['./alocar-valor-administrativo.component.css']
})
export class AlocarValorAdministrativoComponent implements OnInit {
  selectedAccount: any;
  SaldoAtual:any ;
  ValorASerAlocado:any;

  constructor(private http: HttpClient, private constantes: ConstantesService,private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService,
    private web3Service: Web3Service, private router: Router, private zone: NgZone, private ref: ChangeDetectorRef) { 



    let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 1000});
  }

  ngOnInit() {
  }

  async onSubmit(){
    let idConta = await this.web3Service.getIdByAddressSync( await this.web3Service.getCurrentAccountSync());
    
    let verificadoDeMudanca=this.SaldoAtual;
    await this.web3Service.alocaRecursosDesembolso2(idConta,<number>(this.ValorASerAlocado));
    
    this.SaldoAtual = await this.web3Service.getAdminFeeBalance();
    
    
    while(verificadoDeMudanca == this.SaldoAtual){
      this.SaldoAtual = await this.web3Service.getAdminFeeBalance();
    }

  }


  async recuperaContaSelecionada() {

    let self = this;
    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
  
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
  
      this.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + this.selectedAccount);
      self.recuperaSaldoBNDESToken();
      
    }
  
  }  
  
   async recuperaSaldoBNDESToken() {
    this.SaldoAtual = await this.web3Service.getAdminFeeBalance();
    
  }

}
