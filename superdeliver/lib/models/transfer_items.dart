class TransferItem {
  final int id;
  final int store;
  final int tranToStore;
  final String? customer;
  final String? orderNumber;
  final String? item;
  final String? description;
  final int? qtySellingUnits;
  final String? upc;
  final String? createdAt;
  final bool isArchived;

  TransferItem({
    required this.id,
    required this.store,
    required this.tranToStore,
    this.customer,
    this.orderNumber,
    this.item,
    this.description,
    this.qtySellingUnits,
    this.upc,
    this.createdAt,
    required this.isArchived,
  });

  // Factory method to create a TransferItem from JSON
  factory TransferItem.fromJson(Map<String, dynamic> json) {
    return TransferItem(
      id: json['id'],
      store: json['store'],
      tranToStore: json['tran_to_store'],
      customer: json['customer'],
      orderNumber: json['order_number'],
      item: json['item'],
      description: json['description'],
      qtySellingUnits: json['qty_selling_units'],
      upc: json['upc'],
      createdAt: json['created_at'],
      isArchived: json['is_archived'],
    );
  }
}
