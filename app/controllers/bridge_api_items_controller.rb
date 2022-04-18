class BridgeApiItemsController < ApplicationController
  def destroy
    item = BridgeApiItem.find(params[:id])
    item.destroy
    # we need to redirect with a 303 (instead of 302 to avoid the DELETE method to be reused)
    redirect_to(item.user, notice: "Item #{item.item_id} deleted with all its data!", status: 303)
  end
end
