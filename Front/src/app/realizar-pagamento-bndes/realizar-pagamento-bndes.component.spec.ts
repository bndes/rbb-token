import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { RealizarPagamentoBndesComponent } from './realizar-pagamento-bndes.component';

describe('RealizarPagamentoBndesComponent', () => {
  let component: RealizarPagamentoBndesComponent;
  let fixture: ComponentFixture<RealizarPagamentoBndesComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ RealizarPagamentoBndesComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(RealizarPagamentoBndesComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
