import{ PessoaJuridicaHandle} from '../PessoaJuridicaHandle/PessoaJuridicaHandle';

export class DashboardDoacao {
    rbbId: number;  
    razaoSocial: string;
    cnpj: string;
    pessoaJuridica:PessoaJuridicaHandle;
    valor: number;    
    dataHora: Date;
    tipo: string;
    hashID: string;
    uniqueIdentifier: string;
    hashComprovante: string;
    filePathAndName: string;
  }