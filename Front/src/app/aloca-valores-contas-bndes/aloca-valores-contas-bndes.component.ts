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
  selector: 'app-aloca-valores-contas-bndes',
  templateUrl: './aloca-valores-contas-bndes.component.html',
  styleUrls: ['./aloca-valores-contas-bndes.component.css']
})
export class AlocaValoresContasBndesComponent implements OnInit {
  tt:Web3Service ;
//  teste:teste;
  a: any = "1";
  b: any = "1";
  c: any = "1";
  d: any = "1";
  e: any = "1";
  f: any = "1";
  constructor(private http: HttpClient, private constantes: ConstantesService,private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService,
    private web3Service: Web3Service, private router: Router, private zone: NgZone, private ref: ChangeDetectorRef) { 
    this.tt = new Web3Service(http,ConstantesService);

  }

  ngOnInit() {
    
  }
  onSubmit(form){
    this.a = this.web3Service.getAdminFeeBalance(function (result) {console.log("Foi ")},function (error) {console.log("Erro ")});
    


  }
  VerificaA(form){

    console.log(this.a);

  }
 

}
