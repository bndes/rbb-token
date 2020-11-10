import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { RealizarPagamentoComponent } from './realizar-pagamento.component';

describe('RealizarPagamentoComponent', () => {
  let component: RealizarPagamentoComponent;
  let fixture: ComponentFixture<RealizarPagamentoComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ RealizarPagamentoComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(RealizarPagamentoComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
